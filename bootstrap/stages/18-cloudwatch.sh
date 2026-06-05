#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=../bootstrap.env
source "${SCRIPT_DIR}/../bootstrap.env"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/logging.sh"

# Install + configure the Amazon CloudWatch agent to publish memory (plus swap
# and disk) metrics for AWS Compute Optimizer. The agent is configured but NOT
# started here: a systemd ExecCondition (lib drop-in + gate script) starts it at
# boot only when an IAM role is attached, so the AMI bakes clean with no role
# and self-heals when a role is added later.
#
# The .deb is GPG-verified against AWS's committed signing key before install,
# mirroring stage 17. Idempotent: dpkg -i re-installs the same pinned version,
# file installs overwrite deterministically, enable is idempotent.

CONFIG_DIR="${SCRIPT_DIR}/../config/cloudwatch"
CW_KEY="${CONFIG_DIR}/amazon-cloudwatch-agent.gpg"
CW_CONFIG="${CONFIG_DIR}/amazon-cloudwatch-agent.json"
CW_GATE_SRC="${CONFIG_DIR}/cloudwatch-iam-gate.sh"
CW_MOTD_SRC="${CONFIG_DIR}/50-cloudwatch-agent"
CW_DROPIN_SRC="${SCRIPT_DIR}/../config/systemd/amazon-cloudwatch-agent.service.d/iam-gate.conf"

AGENT_CTL="/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl"
GATE_DST="/opt/arm64-bootstrap/bin/cloudwatch-iam-gate"
DROPIN_DST_DIR="/etc/systemd/system/amazon-cloudwatch-agent.service.d"
MOTD_DST="/etc/update-motd.d/50-cloudwatch-agent"

BASE_URL="https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/arm64/${CWAGENT_VERSION}/amazon-cloudwatch-agent.deb"

ARCH="$(dpkg --print-architecture)"
[[ "${ARCH}" == "arm64" ]] || fatal "stage 18 expects arm64, got ${ARCH}"

[[ -f "${CW_KEY}" ]]       || fatal "cloudwatch signing key missing: ${CW_KEY}"
[[ -f "${CW_CONFIG}" ]]    || fatal "cloudwatch config missing: ${CW_CONFIG}"
[[ -f "${CW_GATE_SRC}" ]]  || fatal "cloudwatch gate script missing: ${CW_GATE_SRC}"
[[ -f "${CW_MOTD_SRC}" ]]  || fatal "cloudwatch motd snippet missing: ${CW_MOTD_SRC}"
[[ -f "${CW_DROPIN_SRC}" ]] || fatal "cloudwatch drop-in missing: ${CW_DROPIN_SRC}"

log_info "installing amazon cloudwatch agent ${CWAGENT_VERSION}"

WORK_DIR="$(mktemp -d)"
# Isolated keyring so the import never touches the host's root GPG state.
GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
trap 'rm -rf "${WORK_DIR}" "${GNUPGHOME}"' EXIT

gpg --quiet --import "${CW_KEY}"

curl -fsSL "${BASE_URL}" -o "${WORK_DIR}/cwagent.deb"
curl -fsSL "${BASE_URL}.sig" -o "${WORK_DIR}/cwagent.deb.sig"

# Exit non-zero on a bad/missing signature; under `set -e` this aborts the run.
gpg --verify "${WORK_DIR}/cwagent.deb.sig" "${WORK_DIR}/cwagent.deb" \
  || fatal "cloudwatch agent signature verification failed"

dpkg -i "${WORK_DIR}/cwagent.deb"

[[ -x "${AGENT_CTL}" ]] || fatal "cloudwatch agent ctl not found after install: ${AGENT_CTL}"

# Install the boot-time IAM gate, drop-in, and motd hint BEFORE enabling the
# service, so the ExecCondition path exists the moment systemd could start it.
install -D -m 0755 "${CW_GATE_SRC}" "${GATE_DST}"
install -D -m 0644 "${CW_DROPIN_SRC}" "${DROPIN_DST_DIR}/iam-gate.conf"
install -D -m 0755 "${CW_MOTD_SRC}" "${MOTD_DST}"

systemctl daemon-reload

# Stage the config (translate to runtime TOML). No `-s`: the gate, not this
# stage, decides start/stop. `-m ec2` selects the EC2 metadata mode.
"${AGENT_CTL}" -a fetch-config -m ec2 -c "file:${CW_CONFIG}"

# Enable so boot attempts the unit; the ExecCondition gate decides per boot.
# Do NOT start here: at bake time there is no IAM role and no reboot, so the
# agent never runs during provisioning and never emits a failed PutMetricData.
systemctl enable amazon-cloudwatch-agent.service

log_info "cloudwatch agent installed, configured, enabled, gated (not started)"

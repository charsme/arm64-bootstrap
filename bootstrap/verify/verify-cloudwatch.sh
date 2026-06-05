#!/bin/bash
set -Eeuo pipefail

# Artifact-only checks. Deliberately does NOT assert the service is active or
# that metrics flow: at bake time there is no IAM role, so the agent is
# correctly idle. Asserting runtime here would break clean AMI bakes.

AGENT_CTL="/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl"
AGENT_CONFIG="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
GATE="/opt/arm64-bootstrap/bin/cloudwatch-iam-gate"
DROPIN="/etc/systemd/system/amazon-cloudwatch-agent.service.d/iam-gate.conf"
MOTD="/etc/update-motd.d/50-cloudwatch-agent"

die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

[[ -x "${AGENT_CTL}" ]]    || die "cloudwatch agent ctl missing/not executable: ${AGENT_CTL}"
[[ -f "${AGENT_CONFIG}" ]] || die "cloudwatch agent config not staged: ${AGENT_CONFIG}"
[[ -x "${GATE}" ]]         || die "iam gate missing/not executable: ${GATE}"
[[ -f "${DROPIN}" ]]       || die "ExecCondition drop-in missing: ${DROPIN}"
[[ -x "${MOTD}" ]]         || die "motd snippet missing/not executable: ${MOTD}"

grep -q '^ExecCondition=/opt/arm64-bootstrap/bin/cloudwatch-iam-gate$' "${DROPIN}" \
  || die "drop-in missing expected ExecCondition line: ${DROPIN}"

# Enabled (boot attempts it); active-state is intentionally NOT checked.
systemctl is-enabled --quiet amazon-cloudwatch-agent.service \
  || die "amazon-cloudwatch-agent.service is not enabled"

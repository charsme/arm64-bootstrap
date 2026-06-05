# CloudWatch Agent (Compute Optimizer Memory Metrics) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add bootstrap stage 18 that installs + configures the Amazon CloudWatch agent to publish memory (plus swap/disk) metrics to CloudWatch for AWS Compute Optimizer, gated so it bakes clean with no IAM role and self-heals when a role is attached later.

**Architecture:** Pinned, GPG-verified `.deb` install (mirrors stage 17). Metrics config staged but agent NOT started during bootstrap. A systemd `ExecCondition` drop-in runs an IMDS-based IAM gate at every boot: role present → agent starts; absent → unit cleanly skipped (condition-failed, not failed). A dynamic `update-motd.d` snippet surfaces live state + the fix path. Verification is artifact-only to keep AMI bakes clean.

**Tech Stack:** Bash, systemd drop-ins + ExecCondition, Amazon CloudWatch agent, EC2 IMDSv2, GPG signature verification.

---

## Conventions (read once before starting)

This repo has **no unit-test framework**. CI (`.github/workflows/shellcheck.yml`) runs strict `shellcheck` (`.shellcheckrc`: `severity=style`, `enable=all`, `external-sources=true`, `source-path=SCRIPTDIR`, only `SC1091` disabled) over `bootstrap scripts user-data`. Runtime correctness is checked by on-host scripts in `bootstrap/verify/`. Stage 17 (`17-awscli.sh`) is the reference pattern for a pinned, GPG-verified download stage.

Two verification tiers used throughout this plan:

- **Local/CI (runnable now, on any machine):** `shellcheck <file>`, `bash -n <file>`, and `python3 -m json.tool < <file>` for JSON. Every task includes these.
- **On-host (runnable only on the target EC2 instance after a real bootstrap run):** `bootstrap/verify/verify-cloudwatch.sh` and the reboot behavior matrix in Task 9. These are listed as the final acceptance, not per-task gates.

Every new/edited shell file MUST pass strict shellcheck. When a disable is unavoidable, use a scoped `# shellcheck disable=SCXXXX` with a one-line reason, matching existing stage style.

---

## File Structure

- `bootstrap/bootstrap.env` — add pinned `CWAGENT_VERSION`.
- `bootstrap/config/cloudwatch/amazon-cloudwatch-agent.gpg` — committed AWS signing key (binary).
- `bootstrap/config/cloudwatch/amazon-cloudwatch-agent.json` — metrics config (mem + swap + disk).
- `bootstrap/config/cloudwatch/cloudwatch-iam-gate.sh` — gate script source (installed to `/opt/arm64-bootstrap/bin/cloudwatch-iam-gate`).
- `bootstrap/config/cloudwatch/50-cloudwatch-agent` — `update-motd.d` snippet source (installed to `/etc/update-motd.d/50-cloudwatch-agent`).
- `bootstrap/config/systemd/amazon-cloudwatch-agent.service.d/iam-gate.conf` — systemd drop-in (ExecCondition + network-online ordering).
- `bootstrap/stages/18-cloudwatch.sh` — the stage.
- `bootstrap/verify/verify-cloudwatch.sh` — artifact-only verification.
- `bootstrap/bootstrap.sh` — add stage 18 to STAGES.
- `bootstrap/stages/99-verify.sh` — add `verify-cloudwatch.sh`.
- `docs/operations/deployment-checklist.md` — IAM + Compute Optimizer prerequisites.

---

## Task 1: Pin agent version + commit signing key

**Files:**
- Modify: `bootstrap/bootstrap.env`
- Create: `bootstrap/config/cloudwatch/amazon-cloudwatch-agent.gpg`

- [ ] **Step 1: Add the pinned version to `bootstrap.env`**

Append after the `AWSCLI_VERSION` block (keep the existing trailing `UBUNTU_USER`/`DEFAULT_EDITOR` lines last):

```bash
# Amazon CloudWatch agent version installed by stage 18 from the official S3
# .deb bundle (not in the Ubuntu arm64 apt repo). Pinned exactly for
# reproducible AMIs; bump deliberately. See docs/operations/update-strategy.md.
# Confirmed available at:
#   https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/arm64/<ver>/amazon-cloudwatch-agent.deb
export CWAGENT_VERSION="1.300067.0b1404"
```

- [ ] **Step 2: Fetch and commit AWS's signing key, verifying the fingerprint**

Run:

```bash
mkdir -p bootstrap/config/cloudwatch
curl -fsSL https://amazoncloudwatch-agent.s3.amazonaws.com/assets/amazon-cloudwatch-agent.gpg \
  -o bootstrap/config/cloudwatch/amazon-cloudwatch-agent.gpg
GNUPGHOME="$(mktemp -d)" gpg --show-keys --with-fingerprint \
  bootstrap/config/cloudwatch/amazon-cloudwatch-agent.gpg
```

Expected: output contains uid `Amazon CloudWatch Agent` and fingerprint
`9376 16F3 450B 7D80 6CBD 9725 D581 6730 3B78 9C72`. If the fingerprint differs, STOP — do not commit the key.

- [ ] **Step 3: Verify env file still parses**

Run: `bash -n bootstrap/bootstrap.env && shellcheck bootstrap/bootstrap.env`
Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
git add bootstrap/bootstrap.env bootstrap/config/cloudwatch/amazon-cloudwatch-agent.gpg
git commit -m "feat(cloudwatch): pin CWAGENT_VERSION and commit signing key"
```

---

## Task 2: Metrics config (mem + swap + disk)

**Files:**
- Create: `bootstrap/config/cloudwatch/amazon-cloudwatch-agent.json`

- [ ] **Step 1: Write the config**

```json
{
  "agent": {
    "metrics_collection_interval": 60
  },
  "metrics": {
    "namespace": "CWAgent",
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}"
    },
    "aggregation_dimensions": [["InstanceId"]],
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"]
      },
      "swap": {
        "measurement": ["swap_used_percent"]
      },
      "disk": {
        "measurement": ["disk_used_percent"],
        "resources": ["/", "/data"]
      }
    }
  }
}
```

Note: the `InstanceId` dimension is mandatory — Compute Optimizer only
associates `mem_used_percent` with an instance when that dimension is present.
`${aws:InstanceId}` is a CloudWatch-agent placeholder resolved at runtime; it is
NOT shell — do not quote-mangle it.

- [ ] **Step 2: Validate JSON**

Run: `python3 -m json.tool < bootstrap/config/cloudwatch/amazon-cloudwatch-agent.json > /dev/null && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add bootstrap/config/cloudwatch/amazon-cloudwatch-agent.json
git commit -m "feat(cloudwatch): add metrics config (mem/swap/disk)"
```

---

## Task 3: IAM gate script

**Files:**
- Create: `bootstrap/config/cloudwatch/cloudwatch-iam-gate.sh`

- [ ] **Step 1: Write the gate script**

```bash
#!/bin/bash
set -Eeuo pipefail

# systemd ExecCondition for amazon-cloudwatch-agent.service.
#
# Exit 0  -> an IAM role is attached; let the agent start.
# Exit 1  -> no role (HTTP 404 / empty) or IMDS unreachable; systemd skips the
#            unit cleanly (condition-failed, NOT failed). Re-evaluated every
#            boot, so a later-attached role self-heals on reboot.
#
# Pure IMDSv2 (token-based; IMDSv1 assumed disabled). No awscli dependency.
# IMDS_BASE is overridable to aid on-host debugging; defaults to the link-local
# endpoint.

IMDS_BASE="${IMDS_BASE:-http://169.254.169.254/latest}"

imds_token() {
  curl -fsS -X PUT "${IMDS_BASE}/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 60"
}

has_iam_role() {
  local token role
  token="$(imds_token)" || return 1
  role="$(curl -fsS -H "X-aws-ec2-metadata-token: ${token}" \
    "${IMDS_BASE}/meta-data/iam/security-credentials/")" || return 1
  [[ -n "${role}" ]]
}

if has_iam_role; then
  exit 0
fi
exit 1
```

- [ ] **Step 2: Verify it lints and parses (strict)**

Run: `shellcheck bootstrap/config/cloudwatch/cloudwatch-iam-gate.sh && bash -n bootstrap/config/cloudwatch/cloudwatch-iam-gate.sh && echo OK`
Expected: `OK`, exit 0. If shellcheck flags `SC2310`/`SC2311` on `has_iam_role` in the `if`, add a scoped `# shellcheck disable=` with reason directly above the `if` line; do not restructure the gate.

- [ ] **Step 3: Smoke-test the no-role path locally**

The link-local IMDS endpoint is unreachable off-EC2, so this exercises the
exit-1 path deterministically.

Run: `IMDS_BASE="http://169.254.169.254/latest" bash bootstrap/config/cloudwatch/cloudwatch-iam-gate.sh; echo "exit=$?"`
Expected: `exit=1` (curl fails to reach IMDS → `has_iam_role` returns 1). The positive (role present) path is validated on-host in Task 9.

- [ ] **Step 4: Commit**

```bash
git add bootstrap/config/cloudwatch/cloudwatch-iam-gate.sh
git commit -m "feat(cloudwatch): add IMDS IAM gate for ExecCondition"
```

---

## Task 4: systemd drop-in (ExecCondition + ordering)

**Files:**
- Create: `bootstrap/config/systemd/amazon-cloudwatch-agent.service.d/iam-gate.conf`

- [ ] **Step 1: Write the drop-in**

```ini
# Gate the vendor-managed amazon-cloudwatch-agent.service on an attached IAM
# role. ExecCondition non-zero => unit is skipped cleanly (condition-failed,
# not failed). Drop-in only; the vendor unit file is never replaced.
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
ExecCondition=/opt/arm64-bootstrap/bin/cloudwatch-iam-gate
```

Note: this is a systemd unit file, not shell — not linted by shellcheck, and
the `find ... -name '*.sh'` CI filter skips it. Keep it exact; `ExecCondition`
(not `ExecStartPre`) is what produces the clean skip.

- [ ] **Step 2: Sanity-check the file exists with expected content**

Run: `grep -q '^ExecCondition=/opt/arm64-bootstrap/bin/cloudwatch-iam-gate$' bootstrap/config/systemd/amazon-cloudwatch-agent.service.d/iam-gate.conf && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add bootstrap/config/systemd/amazon-cloudwatch-agent.service.d/iam-gate.conf
git commit -m "feat(cloudwatch): add ExecCondition IAM-gate drop-in"
```

---

## Task 5: update-motd.d hint snippet

**Files:**
- Create: `bootstrap/config/cloudwatch/50-cloudwatch-agent`

- [ ] **Step 1: Write the snippet**

```bash
#!/bin/bash
# Rendered at each login by pam_motd. Reports live CloudWatch agent state and,
# when idle, the most likely cause + fix. Runs as root, so systemctl works.

if systemctl is-active --quiet amazon-cloudwatch-agent.service; then
  printf '\nCloudWatch agent: running (mem/swap/disk -> CWAgent namespace)\n'
else
  printf '\nCloudWatch agent: NOT running.\n'
  printf '  Memory metrics are NOT reaching CloudWatch / Compute Optimizer.\n'
  printf '  Most likely cause: no IAM role attached to this instance.\n'
  printf '  Fix: attach an instance profile with the CloudWatchAgentServerPolicy\n'
  printf '       managed policy, then reboot. The gate re-checks on every boot.\n'
fi
```

- [ ] **Step 2: Verify it lints and parses (strict)**

Run: `shellcheck bootstrap/config/cloudwatch/50-cloudwatch-agent && bash -n bootstrap/config/cloudwatch/50-cloudwatch-agent && echo OK`
Expected: `OK`, exit 0.

(The file has no `.sh` extension, matching `update-motd.d` convention, so CI
will not lint it — but it must still be clean. Run shellcheck manually here.)

- [ ] **Step 3: Commit**

```bash
git add bootstrap/config/cloudwatch/50-cloudwatch-agent
git commit -m "feat(cloudwatch): add dynamic motd hint for agent state"
```

---

## Task 6: The stage script

**Files:**
- Create: `bootstrap/stages/18-cloudwatch.sh`

- [ ] **Step 1: Write the stage**

```bash
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
```

- [ ] **Step 2: Verify it lints and parses (strict)**

Run: `shellcheck bootstrap/stages/18-cloudwatch.sh && bash -n bootstrap/stages/18-cloudwatch.sh && echo OK`
Expected: `OK`, exit 0.

- [ ] **Step 3: Commit**

```bash
git add bootstrap/stages/18-cloudwatch.sh
git commit -m "feat(cloudwatch): add stage 18 install + gate wiring"
```

---

## Task 7: Artifact-only verification script

**Files:**
- Create: `bootstrap/verify/verify-cloudwatch.sh`

- [ ] **Step 1: Write the verify script**

Mirror the existing `bootstrap/verify/*.sh` style (read one first to match
logging/fail idiom; this version sources `lib/logging.sh` for `fatal`).

```bash
#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/logging.sh"

# Artifact-only checks. Deliberately does NOT assert the service is active or
# that metrics flow: at bake time there is no IAM role, so the agent is
# correctly idle. Asserting runtime here would break clean AMI bakes.

AGENT_CTL="/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl"
AGENT_CONFIG="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
GATE="/opt/arm64-bootstrap/bin/cloudwatch-iam-gate"
DROPIN="/etc/systemd/system/amazon-cloudwatch-agent.service.d/iam-gate.conf"
MOTD="/etc/update-motd.d/50-cloudwatch-agent"

log_info "verifying cloudwatch agent artifacts"

[[ -x "${AGENT_CTL}" ]]   || fatal "cloudwatch agent ctl missing/not executable: ${AGENT_CTL}"
[[ -f "${AGENT_CONFIG}" ]] || fatal "cloudwatch agent config not staged: ${AGENT_CONFIG}"
[[ -x "${GATE}" ]]        || fatal "iam gate missing/not executable: ${GATE}"
[[ -f "${DROPIN}" ]]      || fatal "ExecCondition drop-in missing: ${DROPIN}"
[[ -x "${MOTD}" ]]        || fatal "motd snippet missing/not executable: ${MOTD}"

grep -q '^ExecCondition=/opt/arm64-bootstrap/bin/cloudwatch-iam-gate$' "${DROPIN}" \
  || fatal "drop-in missing expected ExecCondition line: ${DROPIN}"

# Enabled (boot attempts it); active-state is intentionally NOT checked.
systemctl is-enabled --quiet amazon-cloudwatch-agent.service \
  || fatal "amazon-cloudwatch-agent.service is not enabled"

log_info "cloudwatch agent artifacts verified"
```

- [ ] **Step 2: Verify it lints and parses (strict)**

Run: `shellcheck bootstrap/verify/verify-cloudwatch.sh && bash -n bootstrap/verify/verify-cloudwatch.sh && echo OK`
Expected: `OK`, exit 0. If `is-enabled --quiet` trips `SC2312`, add a scoped disable with reason, matching how other verify scripts handle pipeline/subshell warnings.

- [ ] **Step 3: Commit**

```bash
git add bootstrap/verify/verify-cloudwatch.sh
git commit -m "feat(cloudwatch): add artifact-only verification"
```

---

## Task 8: Wire stage + verify into orchestration

**Files:**
- Modify: `bootstrap/bootstrap.sh` (STAGES array)
- Modify: `bootstrap/stages/99-verify.sh` (VERIFY_SCRIPTS array)

- [ ] **Step 1: Add stage 18 to the STAGES array**

In `bootstrap/bootstrap.sh`, insert `"18-cloudwatch.sh"` between `"17-awscli.sh"`
and `"99-verify.sh"`:

```bash
  "17-awscli.sh"
  "18-cloudwatch.sh"
  "99-verify.sh"
```

- [ ] **Step 2: Add the verify script to the suite**

In `bootstrap/stages/99-verify.sh`, append to the `VERIFY_SCRIPTS` array (after
`verify-security.sh`):

```bash
  verify-security.sh
  verify-cloudwatch.sh
```

- [ ] **Step 3: Verify both still lint and parse**

Run: `shellcheck bootstrap/bootstrap.sh bootstrap/stages/99-verify.sh && bash -n bootstrap/bootstrap.sh bootstrap/stages/99-verify.sh && echo OK`
Expected: `OK`, exit 0.

- [ ] **Step 4: Run the full repo shellcheck gate (matches CI exactly)**

Run:

```bash
find bootstrap scripts user-data -name '*.sh' -print0 | xargs -0 -r shellcheck && echo "CI-CLEAN"
```

Expected: `CI-CLEAN`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add bootstrap/bootstrap.sh bootstrap/stages/99-verify.sh
git commit -m "feat(cloudwatch): wire stage 18 + verify into orchestration"
```

---

## Task 9: Document prerequisites + on-host acceptance

**Files:**
- Modify: `docs/operations/deployment-checklist.md`

- [ ] **Step 1: Read the current checklist to match its format**

Run: `cat docs/operations/deployment-checklist.md`
Identify the section structure (headings, list style) before editing.

- [ ] **Step 2: Add a CloudWatch / Compute Optimizer prerequisites subsection**

Append a section matching the document's existing heading/list style, covering:

```markdown
## CloudWatch Agent / Compute Optimizer (memory metrics)

Stage 18 installs and configures the CloudWatch agent but starts it only when an
IAM role is attached (boot-time ExecCondition gate). For memory metrics to reach
Compute Optimizer:

- [ ] Attach an instance profile whose role includes the AWS managed policy
      `CloudWatchAgentServerPolicy` (grants `cloudwatch:PutMetricData` etc.).
- [ ] Reboot if the role was attached after first boot — the gate re-checks
      every boot and starts the agent once a role is present.
- [ ] Enable AWS Compute Optimizer for the account/region (one-time, AWS
      Console or `aws compute-optimizer update-enrollment-status --status Active`).
- [ ] Allow the observation window: Compute Optimizer needs several days of
      `mem_used_percent` data before emitting a memory recommendation.

Known limitation: the gate detects role *presence*, not whether the role grants
`cloudwatch:PutMetricData`. A present-but-under-permissioned role lets the agent
start while `PutMetricData` returns 403 (visible in
`/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log`); the login
motd still reports "running".
```

- [ ] **Step 3: Commit**

```bash
git add docs/operations/deployment-checklist.md
git commit -m "docs(cloudwatch): document IAM + Compute Optimizer prerequisites"
```

- [ ] **Step 4: On-host acceptance (run on a real EC2 instance after bootstrap)**

These cannot run on a dev machine. Execute on the target instance after a full
bootstrap run. Record results in the PR description.

Bake / no-role (or run bootstrap, do not attach a role):

```bash
sudo bash bootstrap/verify/verify-cloudwatch.sh   # expect: artifacts verified, exit 0
systemctl is-enabled amazon-cloudwatch-agent.service   # expect: enabled
systemctl is-active amazon-cloudwatch-agent.service    # expect: inactive
sudo systemctl start amazon-cloudwatch-agent.service   # ExecCondition runs
systemctl show -p ConditionResult --value amazon-cloudwatch-agent.service  # expect: no (condition-failed)
run-parts /etc/update-motd.d/ 2>/dev/null | grep -A4 'CloudWatch agent'     # expect: NOT running + fix hint
```

With role (attach instance profile w/ CloudWatchAgentServerPolicy, then reboot):

```bash
systemctl is-active amazon-cloudwatch-agent.service    # expect: active
IMDS_BASE="http://169.254.169.254/latest" /opt/arm64-bootstrap/bin/cloudwatch-iam-gate; echo $?  # expect: 0
run-parts /etc/update-motd.d/ 2>/dev/null | grep 'CloudWatch agent'   # expect: running
# After a few minutes, confirm the metric landed:
aws cloudwatch list-metrics --namespace CWAgent --metric-name mem_used_percent \
  --dimensions Name=InstanceId,Value="$(curl -fsS -H "X-aws-ec2-metadata-token: $(curl -fsS -X PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')" http://169.254.169.254/latest/meta-data/instance-id)"
# expect: a metric entry returned
```

Self-heal: launch an instance from the AMI with NO role → agent inactive +
motd hint; attach role + reboot → agent active. Confirms the boot gate.

---

## Self-Review (completed during authoring)

- **Spec coverage:** behavior contract (Tasks 6/3/4 + Task 9 matrix), boot gate (Tasks 3/4), pinned GPG install (Tasks 1/6), metrics config mem+swap+disk (Task 2), motd hint (Task 5), artifact-only verify + wiring (Tasks 7/8), out-of-scope prerequisites + known limitation (Task 9). All spec sections mapped.
- **Placeholder scan:** none — version `1.300067.0b1404`, fingerprint, URLs, and all code are concrete.
- **Name/path consistency:** gate source `cloudwatch-iam-gate.sh` → installed `/opt/arm64-bootstrap/bin/cloudwatch-iam-gate`, referenced identically in stage (Task 6), drop-in (Task 4), verify (Task 7), and acceptance (Task 9). Service name `amazon-cloudwatch-agent.service`, namespace `CWAgent`, and config path `/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json` are consistent across tasks.
```

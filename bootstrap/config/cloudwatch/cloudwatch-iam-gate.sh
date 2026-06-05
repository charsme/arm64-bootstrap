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

# NOTE: imds_token is intentionally duplicated from bootstrap/lib/aws.sh —
# this script is installed standalone and cannot source repo libs at boot.
imds_token() {
  curl -fsS --connect-timeout 2 --max-time 5 -X PUT "${IMDS_BASE}/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 60"
}

has_iam_role() {
  local token role
  # shellcheck disable=SC2310 # imds_token used in || fallback inside a function; set -e disabled here intentionally
  token="$(imds_token)" || return 1
  role="$(curl -fsS --connect-timeout 2 --max-time 5 -H "X-aws-ec2-metadata-token: ${token}" \
    "${IMDS_BASE}/meta-data/iam/security-credentials/")" || return 1
  [[ -n "${role}" ]]
}

# shellcheck disable=SC2310 # has_iam_role return value used in if-condition; set -e behaviour is intentional
if has_iam_role; then
  exit 0
fi
exit 1

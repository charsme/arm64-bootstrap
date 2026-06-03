#!/bin/bash
set -Eeuo pipefail

# AWS EC2 instance-metadata helpers (IMDSv2, token-based).
#
# Pure IMDS over curl — no awscli dependency, usable from any stage that
# needs instance identity or placement. IMDSv1 is assumed disabled, so every
# read uses a short-lived session token. Functions fail loud: a curl error
# propagates a non-zero exit to the caller (which runs under `set -e`).
#
# Not sourced by any stage yet — this is the AWS primitive layer that future
# stages (e.g. tag-based EBS discovery) build on.

IMDS_BASE="http://169.254.169.254/latest"

# Fetch a short-lived IMDSv2 session token (60s TTL).
imds_token() {
  curl -fsS -X PUT "${IMDS_BASE}/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 60"
}

# Read a metadata path, e.g. `imds_get meta-data/instance-id`.
imds_get() {
  local path="$1" token
  token="$(imds_token)"
  curl -fsS -H "X-aws-ec2-metadata-token: ${token}" \
    "${IMDS_BASE}/${path}"
}

# Convenience accessors for the identity fields stages care about.
instance_id()     { imds_get meta-data/instance-id; }
instance_type()   { imds_get meta-data/instance-type; }
instance_region() { imds_get meta-data/placement/region; }
instance_az()     { imds_get meta-data/placement/availability-zone; }

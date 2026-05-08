#!/bin/bash
set -Eeuo pipefail

acquire_lock() {
  local lock_file="/var/run/arm64-bootstrap.lock"

  exec 200>"${lock_file}"

  flock -n 200 \
    || fatal "another bootstrap process is already running"
}

detect_architecture() {
  local arch
  arch="$(uname -m)"

  [[ "${arch}" == "aarch64" ]] \
    || fatal "unsupported architecture: ${arch}"
}

detect_os() {
  require_file "/etc/os-release"

  # shellcheck source=/dev/null
  source /etc/os-release

  [[ "${ID}" == "ubuntu" ]] \
    || fatal "unsupported OS: ${ID}"

  [[ "${VERSION_ID}" == "26.04" ]] \
    || fatal "unsupported ubuntu version: ${VERSION_ID}"
}

write_bootstrap_version_file() {
  cat >/etc/bootstrap-version <<EOF
BOOTSTRAP_VERSION=${BOOTSTRAP_VERSION}
BOOTSTRAP_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOSTNAME=$(hostname)
EOF
}

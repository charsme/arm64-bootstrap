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

# shellcheck disable=SC2154
detect_os() {
  require_file "/etc/os-release"

  # shellcheck source=/dev/null
  source /etc/os-release

  [[ "${ID}" == "ubuntu" ]] \
    || fatal "unsupported OS: ${ID}"

  [[ "${VERSION_ID}" == "26.04" ]] \
    || fatal "unsupported ubuntu version: ${VERSION_ID}"
}

# shellcheck disable=SC2154
write_bootstrap_version_file() {
  local bootstrap_date bootstrap_hostname
  bootstrap_date="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  bootstrap_hostname="$(hostname)"

  cat >/etc/bootstrap-version <<EOF
BOOTSTRAP_VERSION=${BOOTSTRAP_VERSION}
BOOTSTRAP_DATE=${bootstrap_date}
HOSTNAME=${bootstrap_hostname}
EOF
}

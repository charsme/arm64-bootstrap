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

  local allowed match=0
  for allowed in "${ALLOWED_UBUNTU_VERSIONS[@]}"; do
    if [[ "${VERSION_ID}" == "${allowed}" ]]; then
      match=1
      break
    fi
  done

  (( match == 1 )) \
    || fatal "unsupported ubuntu version: ${VERSION_ID} (allowed: ${ALLOWED_UBUNTU_VERSIONS[*]})"
}

# Total physical memory in bytes, read from /proc/meminfo MemTotal (kB).
get_mem_total_bytes() {
  awk '/^MemTotal:/ { printf "%d", $2 * 1024 }' /proc/meminfo
}

# Size of the filesystem containing the given path, in bytes.
get_fs_size_bytes() {
  local path="$1"
  df -PB1 "${path}" | awk 'NR==2 { print $2 }'
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

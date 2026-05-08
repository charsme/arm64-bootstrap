#!/bin/bash
set -Eeuo pipefail

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "must run as root" >&2
    exit 1
  fi
}

require_command() {
  local cmd="$1"

  command -v "${cmd}" >/dev/null 2>&1 \
    || fatal "required command missing: ${cmd}"
}

require_file() {
  local path="$1"

  [[ -f "${path}" ]] \
    || fatal "required file missing: ${path}"
}

require_directory() {
  local path="$1"

  [[ -d "${path}" ]] \
    || fatal "required directory missing: ${path}"
}

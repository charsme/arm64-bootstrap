#!/bin/bash
set -Eeuo pipefail

# shellcheck disable=SC2154,SC2312
init_logging() {
  mkdir -p "${BOOTSTRAP_LOG_DIR}"

  touch "${BOOTSTRAP_LOG_FILE}"

  exec > >(tee -a "${BOOTSTRAP_LOG_FILE}") 2>&1
}

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# shellcheck disable=SC2312
log_info() {
  printf '[%s] [INFO] %s\n' "$(timestamp)" "$*"
}

# shellcheck disable=SC2312
log_warn() {
  printf '[%s] [WARN] %s\n' "$(timestamp)" "$*" >&2
}

# shellcheck disable=SC2312
log_error() {
  printf '[%s] [ERROR] %s\n' "$(timestamp)" "$*" >&2
}

fatal() {
  log_error "$*"
  exit 1
}

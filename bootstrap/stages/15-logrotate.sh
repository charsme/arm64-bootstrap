#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../lib/logging.sh"

log_info "configuring logrotate"

LOGROTATE_CONF_DIR="${SCRIPT_DIR}/../config/logrotate"

# Global logrotate.conf
cp "${LOGROTATE_CONF_DIR}/logrotate.conf" /etc/logrotate.conf

# Bootstrap-owned logrotate.d files
LOGROTATE_FILES=(
  bootstrap
  docker-prune
  alternatives
  apt
  dpkg
  dracut-core
  unattended-upgrades
  ubuntu-pro-client
  bootlog
  chrony
)

for f in "${LOGROTATE_FILES[@]}"; do
  cp "${LOGROTATE_CONF_DIR}/${f}" "/etc/logrotate.d/${f}"
done

logrotate --debug /etc/logrotate.conf 2>&1 | grep -E "^error" && {
  log_error "logrotate config validation failed"
  exit 1
} || true

log_info "logrotate configured"

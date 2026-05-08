#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../lib/logging.sh"

log_info "configuring zram"

cp \
  "${SCRIPT_DIR}/../config/zram/zram-generator.conf" \
  /etc/systemd/zram-generator.conf

systemctl daemon-reload

systemctl restart systemd-zram-setup@zram0.service || true

swapon --show

if ! swapon --show | grep -q zram; then
  log_warn "zram swap not active; may activate on next daemon-reload or reboot"
fi

log_info "zram configured"

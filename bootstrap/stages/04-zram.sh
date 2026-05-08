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

log_info "zram configured"

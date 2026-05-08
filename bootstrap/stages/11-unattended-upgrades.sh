#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../lib/logging.sh"

log_info "configuring unattended upgrades"

cp \
  "${SCRIPT_DIR}/../config/unattended-upgrades/20auto-upgrades" \
  /etc/apt/apt.conf.d/20auto-upgrades

cp \
  "${SCRIPT_DIR}/../config/unattended-upgrades/50unattended-upgrades" \
  /etc/apt/apt.conf.d/50unattended-upgrades

systemctl enable unattended-upgrades
systemctl restart unattended-upgrades

log_info "unattended upgrades configured"

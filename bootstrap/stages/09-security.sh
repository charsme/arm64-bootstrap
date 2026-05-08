#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../lib/logging.sh"

log_info "applying ssh hardening"

mkdir -p /etc/ssh/sshd_config.d

cp \
  "${SCRIPT_DIR}/../config/ssh/hardening.conf" \
  /etc/ssh/sshd_config.d/bootstrap.conf

sshd -t

systemctl restart ssh

log_info "ssh hardening applied"

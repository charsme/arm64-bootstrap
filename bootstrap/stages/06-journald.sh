#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../lib/logging.sh"

log_info "configuring journald"

mkdir -p /etc/systemd/journald.conf.d

cp \
  "${SCRIPT_DIR}/../config/journald/journald.conf" \
  /etc/systemd/journald.conf.d/bootstrap.conf

systemctl restart systemd-journald

log_info "journald configured"

#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../lib/logging.sh"

log_info "installing cleanup timers"

cp \
  "${SCRIPT_DIR}/../config/systemd/docker-cleanup.service" \
  /etc/systemd/system/docker-cleanup.service

cp \
  "${SCRIPT_DIR}/../config/systemd/docker-cleanup.timer" \
  /etc/systemd/system/docker-cleanup.timer

systemctl daemon-reload

systemctl enable docker-cleanup.timer
systemctl start docker-cleanup.timer

log_info "cleanup timers configured"

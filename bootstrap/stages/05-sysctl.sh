#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../lib/logging.sh"

log_info "applying sysctl tuning"

cp \
  "${SCRIPT_DIR}/../config/sysctl/99-bootstrap.conf" \
  /etc/sysctl.d/99-bootstrap.conf

sysctl --system

log_info "sysctl tuning applied"

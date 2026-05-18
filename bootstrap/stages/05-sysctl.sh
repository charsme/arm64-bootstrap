#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../lib/logging.sh"

log_info "loading required kernel modules"

cat >/etc/modules-load.d/docker.conf <<EOF
br_netfilter
overlay
EOF

modprobe br_netfilter 2>/dev/null || log_warn "br_netfilter not available; will load at Docker start"
modprobe overlay 2>/dev/null || log_warn "overlay not available; will load at Docker start"

log_info "applying sysctl tuning"

# Bootstrap baseline at 50- so operator drop-ins (99-) override intentionally.
cp \
  "${SCRIPT_DIR}/../config/sysctl/50-bootstrap.conf" \
  /etc/sysctl.d/50-bootstrap.conf

# Remove pre-rename orphan from older bootstrap runs to avoid double-load.
rm -f /etc/sysctl.d/99-bootstrap.conf

sysctl --system

log_info "sysctl tuning applied"

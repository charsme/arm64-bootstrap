#!/bin/bash
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/logging.sh"

log_info "enabling fstrim timer"

systemctl enable fstrim.timer
systemctl start fstrim.timer

log_info "fstrim enabled"

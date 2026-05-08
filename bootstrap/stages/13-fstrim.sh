#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/logging.sh"

log_info "enabling fstrim timer"

systemctl enable fstrim.timer
systemctl start fstrim.timer

log_info "fstrim enabled"

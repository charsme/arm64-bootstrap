#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/bootstrap.env"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/validation.sh"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/system.sh"

STAGES=(
  "00-preflight.sh"
  "01-system-update.sh"
  "02-packages.sh"
  "03-storage.sh"
  "04-zram.sh"
  "05-sysctl.sh"
  "06-journald.sh"
  "07-docker-install.sh"
  "08-docker-config.sh"
  "09-security.sh"
  "10-ohmyzsh.sh"
  "11-unattended-upgrades.sh"
  "12-cleanup-timers.sh"
  "13-fstrim.sh"
  "14-motd.sh"
  "99-verify.sh"
)

run_stage() {
  local stage="$1"

  log_info "=================================================="
  log_info "RUNNING STAGE: ${stage}"
  log_info "=================================================="

  bash "${SCRIPT_DIR}/stages/${stage}"

  log_info "STAGE COMPLETE: ${stage}"
}

main() {
  require_root
  acquire_lock
  init_logging

  log_info "bootstrap version: ${BOOTSTRAP_VERSION}"

  for stage in "${STAGES[@]}"; do
    run_stage "${stage}"
  done

  log_info "bootstrap completed successfully"
}

main "$@"

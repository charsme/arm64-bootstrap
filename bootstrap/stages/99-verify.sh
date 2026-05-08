#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../lib/logging.sh"

VERIFY_SCRIPTS=(
  verify-bootstrap.sh
  verify-storage.sh
  verify-docker.sh
  verify-network.sh
  verify-security.sh
)

log_info "running verification suite"

for script in "${VERIFY_SCRIPTS[@]}"; do
  log_info "running ${script}"

  bash "${SCRIPT_DIR}/../verify/${script}"
done

log_info "all verification checks passed"

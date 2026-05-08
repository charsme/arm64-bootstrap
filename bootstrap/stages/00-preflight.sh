#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../bootstrap.env"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/logging.sh"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/system.sh"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/validation.sh"

log_info "running preflight checks"

require_root

detect_architecture

detect_os

mkdir -p "${BOOTSTRAP_LOG_DIR}"

write_bootstrap_version_file

log_info "preflight checks passed"

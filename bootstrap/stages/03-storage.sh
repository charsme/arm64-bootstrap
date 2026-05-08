#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../bootstrap.env"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/logging.sh"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/disks.sh"

log_info "starting storage provisioning"

DATA_DEVICE="$(detect_data_device)"

log_info "detected data device: ${DATA_DEVICE}"

format_device_if_needed "${DATA_DEVICE}"

ensure_mountpoint

mount_data_device "${DATA_DEVICE}"

ensure_data_marker

verify_data_mount

ensure_data_layout

ensure_home_symlink

log_info "storage provisioning complete"

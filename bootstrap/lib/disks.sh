#!/bin/bash
set -Eeuo pipefail

get_root_device() {
  findmnt -n -o SOURCE /
}

list_candidate_data_devices() {
  local root_device
  root_device="$(get_root_device)"

  lsblk -dpno NAME,TYPE \
    | awk '$2 == "disk" { print $1 }' \
    | grep -v "^${root_device}$"
}

detect_data_device() {
  local devices
  mapfile -t devices < <(list_candidate_data_devices)

  if [[ "${#devices[@]}" -eq 0 ]]; then
    fatal "no candidate data device found"
  fi

  if [[ "${#devices[@]}" -gt 1 ]]; then
    fatal "ambiguous data device detection"
  fi

  echo "${devices[0]}"
}

device_has_filesystem() {
  local device="$1"

  blkid "${device}" >/dev/null 2>&1
}

format_device_if_needed() {
  local device="$1"

  if device_has_filesystem "${device}"; then
    log_info "filesystem already exists on ${device}"
    return
  fi

  log_warn "formatting device ${device} as ext4"

  mkfs.ext4 -F -L DATA "${device}"
}

get_device_uuid() {
  local device="$1"

  blkid -s UUID -o value "${device}"
}

ensure_mountpoint() {
  mkdir -p "${DATA_MOUNT}"
}

mount_data_device() {
  local device="$1"
  local uuid

  uuid="$(get_device_uuid "${device}")"

  grep -q "${uuid}" /etc/fstab \
    || echo "UUID=${uuid} ${DATA_MOUNT} ext4 defaults,nofail,x-systemd.device-timeout=30 0 2" >> /etc/fstab

  mountpoint -q "${DATA_MOUNT}" \
    || mount "${DATA_MOUNT}"
}

ensure_data_marker() {
  touch "${DATA_MARKER_FILE}"
}

verify_data_mount() {
  mountpoint -q "${DATA_MOUNT}" \
    || fatal "/data is not mounted"

  [[ -f "${DATA_MARKER_FILE}" ]] \
    || fatal "data marker missing"
}

ensure_data_layout() {
  mkdir -p \
    /data/docker \
    /data/stacks \
    /data/volumes \
    /data/workspaces \
    /data/repos \
    /data/cache \
    /data/backups \
    /data/logs \
    /data/tmp

  chown root:root /data/docker

  chown -R ubuntu:ubuntu \
    /data/stacks \
    /data/volumes \
    /data/workspaces \
    /data/repos \
    /data/cache \
    /data/backups \
    /data/logs \
    /data/tmp
}

ensure_home_symlink() {
  local link_path="/home/ubuntu/data"

  if [[ -e "${link_path}" ]] && [[ ! -L "${link_path}" ]]; then
    fatal "conflicting path exists: ${link_path}"
  fi

  ln -sfn /data "${link_path}"

  chown -h ubuntu:ubuntu "${link_path}"
}

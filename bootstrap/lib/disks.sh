#!/bin/bash
set -Eeuo pipefail

get_root_disk() {
  local src type pkname
  src="$(findmnt -n -o SOURCE /)"
  type="$(lsblk -no TYPE "${src}" 2>/dev/null | head -1)"

  if [[ "${type}" == "disk" ]]; then
    echo "${src}"
    return
  fi

  pkname="$(lsblk -no PKNAME "${src}" | head -1)"
  [[ -n "${pkname}" ]] || fatal "cannot determine root disk from ${src}"
  echo "/dev/${pkname}"
}

list_candidate_data_devices() {
  local root_disk
  root_disk="$(get_root_disk)"

  lsblk -dpno NAME,TYPE \
    | awk '$2 == "disk" { print $1 }' \
    | grep -v "^${root_disk}$" \
    | grep -v "^/dev/zram"
}

detect_data_device() {
  local devices
  # fatal() inside list_candidate_data_devices exits before mapfile on error.
  # shellcheck disable=SC2312
  mapfile -t devices < <(list_candidate_data_devices)

  if [[ "${#devices[@]}" -eq 0 ]]; then
    fatal "no candidate data device found"
  fi

  if [[ "${#devices[@]}" -gt 1 ]]; then
    fatal "ambiguous data device detection"
  fi

  echo "${devices[0]}"
}

format_device_if_needed() {
  local device="$1"

  if blkid "${device}" >/dev/null 2>&1; then
    log_info "filesystem already exists on ${device}"
    return
  fi

  log_warn "formatting device ${device} as ext4"

  mkfs.ext4 -F -L DATA "${device}"
}

get_device_uuid() {
  local device="$1"
  local uuid

  uuid="$(blkid -s UUID -o value "${device}")"
  [[ -n "${uuid}" ]] || fatal "cannot get UUID for device ${device}"
  echo "${uuid}"
}

# shellcheck disable=SC2154
ensure_mountpoint() {
  mkdir -p "${DATA_MOUNT}"
}

# shellcheck disable=SC2154
mount_data_device() {
  local device="$1"
  local uuid
  local fstab_entry

  uuid="$(get_device_uuid "${device}")"
  fstab_entry="UUID=${uuid} ${DATA_MOUNT} ext4 defaults,nofail,x-systemd.device-timeout=30 0 2"

  if grep -qE "^\S+[[:space:]]+${DATA_MOUNT}[[:space:]]" /etc/fstab; then
    grep -q "UUID=${uuid}" /etc/fstab \
      || fatal "fstab has existing entry for ${DATA_MOUNT} with a different UUID; manual intervention required"
    log_info "fstab entry for ${DATA_MOUNT} already present and matches"
  else
    printf '\n%s\n' "${fstab_entry}" >> /etc/fstab
    log_info "fstab entry for ${DATA_MOUNT} added"
  fi

  mountpoint -q "${DATA_MOUNT}" \
    || mount "${DATA_MOUNT}"
}

# shellcheck disable=SC2154
ensure_data_marker() {
  touch "${DATA_MARKER_FILE}"
}

# shellcheck disable=SC2154
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

  chown ubuntu:ubuntu \
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

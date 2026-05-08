#!/bin/bash
set -Eeuo pipefail

docker_data_root() {
  docker info --format '{{ .DockerRootDir }}'
}

verify_docker_data_root() {
  local root
  root="$(docker_data_root)"

  [[ "${root}" == "${DATA_DOCKER_ROOT}" ]] \
    || fatal "docker root mismatch: ${root}"
}

verify_docker_running() {
  systemctl is-active --quiet docker \
    || fatal "docker service is not active"
}

block_docker_if_data_missing() {
  verify_data_mount
}

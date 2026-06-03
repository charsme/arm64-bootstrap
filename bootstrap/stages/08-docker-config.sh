#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=../bootstrap.env
source "${SCRIPT_DIR}/../bootstrap.env"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/logging.sh"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/disks.sh"

verify_data_mount

log_info "configuring docker"

mkdir -p /etc/docker

# /etc/docker/daemon.json is generated here from bootstrap.env so the
# default-address-pools track DOCKER_POOL_*_BASE/SIZE and reruns reconcile
# pool changes (e.g., VPC CIDR conflict resolution) without manual edits.
generate_docker_daemon_json() {
  cat >/etc/docker/daemon.json <<EOF
{
  "data-root": "${DATA_DOCKER_ROOT}",
  "live-restore": true,
  "log-driver": "local",
  "log-opts": {
    "max-size": "20m",
    "max-file": "5"
  },
  "features": {
    "buildkit": true
  },
  "registry-mirrors": [
    "https://public.ecr.aws",
    "https://mirror.gcr.io"
  ],
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Soft": 1048576,
      "Hard": 1048576
    },
    "nproc": {
      "Name": "nproc",
      "Soft": 65535,
      "Hard": 65535
    }
  },
  "default-address-pools": [
    {
      "base": "${DOCKER_POOL_1_BASE}",
      "size": ${DOCKER_POOL_1_SIZE}
    },
    {
      "base": "${DOCKER_POOL_2_BASE}",
      "size": ${DOCKER_POOL_2_SIZE}
    }
  ]
}
EOF
}

generate_docker_daemon_json

mkdir -p /etc/systemd/system/docker.service.d

cp \
  "${SCRIPT_DIR}/../config/systemd/docker.service.d/override.conf" \
  /etc/systemd/system/docker.service.d/override.conf

cat >/etc/profile.d/docker-buildkit.sh <<EOF
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
EOF

systemctl daemon-reload

systemctl restart containerd
systemctl restart docker

log_info "docker configured (pools: ${DOCKER_POOL_1_BASE}/${DOCKER_POOL_1_SIZE}, ${DOCKER_POOL_2_BASE}/${DOCKER_POOL_2_SIZE})"

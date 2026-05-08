#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../bootstrap.env"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/logging.sh"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/disks.sh"

verify_data_mount

log_info "configuring docker"

mkdir -p /etc/docker

cp \
  "${SCRIPT_DIR}/../config/docker/daemon.json" \
  /etc/docker/daemon.json

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

log_info "docker configured"

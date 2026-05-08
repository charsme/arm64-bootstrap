#!/bin/bash
set -Eeuo pipefail

systemctl is-active --quiet docker

docker info --format '{{ .DockerRootDir }}' \
  | grep -q '^/data/docker$'

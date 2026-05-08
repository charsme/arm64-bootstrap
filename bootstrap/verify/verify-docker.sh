#!/bin/bash
set -Eeuo pipefail

docker info --format '{{ .DockerRootDir }}' \
  | grep -q '^/data/docker$'

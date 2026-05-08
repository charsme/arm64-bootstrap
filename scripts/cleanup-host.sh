#!/bin/bash
set -Eeuo pipefail

echo "[INFO] running manual cleanup"

docker system prune -f --filter "until=168h" || true
docker builder prune -f --filter "until=168h" || true

echo "[INFO] cleanup complete"

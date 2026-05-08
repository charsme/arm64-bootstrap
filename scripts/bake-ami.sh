#!/bin/bash
set -Eeuo pipefail

# This script is intentionally conservative.
# It prepares the host for a clean AMI snapshot after bootstrap succeeds.

echo "[INFO] stopping nonessential runtime noise"
systemctl stop docker-cleanup.timer || true
systemctl stop fstrim.timer || true

echo "[INFO] verifying bootstrap state"
bash /home/ubuntu/arm64-bootstrap/bootstrap/verify/verify-bootstrap.sh
bash /home/ubuntu/arm64-bootstrap/bootstrap/verify/verify-storage.sh
bash /home/ubuntu/arm64-bootstrap/bootstrap/verify/verify-docker.sh
bash /home/ubuntu/arm64-bootstrap/bootstrap/verify/verify-network.sh
bash /home/ubuntu/arm64-bootstrap/bootstrap/verify/verify-security.sh

echo "[INFO] cleaning transient runtime state"
docker system prune -f || true
docker builder prune -f || true

echo "[INFO] AMI bake preparation complete"

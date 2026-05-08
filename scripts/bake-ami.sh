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

echo "[INFO] removing /data fstab entry"
# The AMI snapshots the root volume only. Baking a specific EBS UUID into
# fstab means any instance launched from this AMI will fail bootstrap rerun
# (different UUID on the new data EBS). Strip the entry so instances launch
# clean and stage 03 populates fstab with the correct UUID on first run.
sed -i '\,^[^#].*[[:space:]]/data[[:space:]],d' /etc/fstab

echo "[INFO] AMI bake preparation complete"

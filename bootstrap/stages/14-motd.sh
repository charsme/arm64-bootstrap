#!/bin/bash
set -Eeuo pipefail

cat >/etc/motd <<'EOF'
ARM64 Ubuntu 26 Bootstrap Host

/data volume required
Docker runtime stored under /data/docker

Use:
  docker compose
  systemctl
  journalctl

Bootstrap:
  /var/log/bootstrap/bootstrap.log
EOF

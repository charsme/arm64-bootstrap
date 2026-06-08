#!/bin/bash
set -Eeuo pipefail

# Derive the OS label from the running system so the motd is correct on every
# supported release (24.04 noble, 26.04 resolute, ...). Quoted-heredoc would
# freeze a single version string; an unquoted heredoc interpolates PRETTY_NAME.
# shellcheck source=/dev/null
. /etc/os-release

# PRETTY_NAME is set by the sourced os-release; shellcheck cannot see it.
# shellcheck disable=SC2154
cat >/etc/motd <<EOF
ARM64 ${PRETTY_NAME:-Ubuntu} Bootstrap Host

/data volume required
Docker runtime stored under /data/docker

Use:
  docker compose
  node
  systemctl
  journalctl

Bootstrap:
  /var/log/bootstrap/bootstrap.log
EOF

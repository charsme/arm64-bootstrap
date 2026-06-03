#!/bin/bash
set -Eeuo pipefail

test -f /etc/bootstrap-version

test -d /var/log/bootstrap

command -v node >/dev/null

command -v npm >/dev/null

command -v aws >/dev/null

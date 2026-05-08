#!/bin/bash
set -Eeuo pipefail

test -f /etc/bootstrap-version

test -d /var/log/bootstrap

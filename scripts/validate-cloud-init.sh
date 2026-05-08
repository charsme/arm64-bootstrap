#!/bin/bash
set -Eeuo pipefail

if command -v cloud-init >/dev/null 2>&1; then
  cloud-init status --long
  cloud-init analyze show || true
else
  echo "cloud-init is not installed"
fi

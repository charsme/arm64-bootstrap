#!/bin/bash
set -Eeuo pipefail

mountpoint -q /data

test -f /data/.mounted-data-volume

#!/bin/bash
set -Eeuo pipefail

sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"

sysctl net.ipv4.ip_forward | grep -q "= 1"

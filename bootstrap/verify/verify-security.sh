#!/bin/bash
set -Eeuo pipefail

sshd -T | grep -q "passwordauthentication no"

sshd -T | grep -q "permitrootlogin no"

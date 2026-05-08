#!/bin/bash
set -Eeuo pipefail

sshd_config="$(sshd -T -C "user=root,addr=127.0.0.1,host=localhost,laddr=127.0.0.1,lport=22")"

grep -q "passwordauthentication no" <<< "${sshd_config}"
grep -q "permitrootlogin no" <<< "${sshd_config}"

#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=../bootstrap.env
source "${SCRIPT_DIR}/../bootstrap.env"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/logging.sh"

log_info "installing node ${NODE_MAJOR}.x (LTS) from nodesource"

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
  | gpg --batch --yes --dearmor \
  -o /etc/apt/keyrings/nodesource.gpg

chmod a+r /etc/apt/keyrings/nodesource.gpg

cat >/etc/apt/sources.list.d/nodesource.list <<EOF
deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main
EOF

apt-get update

apt-get install -y nodejs

log_info "node installed"

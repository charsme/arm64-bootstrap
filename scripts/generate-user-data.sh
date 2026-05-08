#!/bin/bash
set -Eeuo pipefail

cat <<'EOF'
#!/bin/bash
set -Eeuo pipefail

exec > >(tee -a /var/log/user-data.log) 2>&1

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y git curl ca-certificates

cd /home/ubuntu

if [[ ! -d arm64-bootstrap ]]; then
  git clone https://github.com/charsme/arm64-bootstrap.git
fi

cd arm64-bootstrap

git pull --ff-only

chmod +x bootstrap/bootstrap.sh

sudo bash bootstrap/bootstrap.sh
EOF

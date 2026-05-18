#!/bin/bash
set -Eeuo pipefail

# Allow cloud-init (or an operator) to override repo source by writing
# /etc/default/arm64-bootstrap before this script runs. File is a plain
# shell snippet: LOG_FILE=... REPO_DIR=... REPO_URL=... REPO_BRANCH=...
# Missing file is fine; defaults below apply.
if [[ -f /etc/default/arm64-bootstrap ]]; then
  # shellcheck source=/dev/null
  source /etc/default/arm64-bootstrap
fi

LOG_FILE="${LOG_FILE:-/var/log/user-data.log}"
REPO_DIR="${REPO_DIR:-/home/ubuntu/arm64-bootstrap}"
REPO_URL="${REPO_URL:-https://github.com/charsme/arm64-bootstrap.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"

# shellcheck disable=SC2312
exec > >(tee -a "${LOG_FILE}" | logger -t user-data -s 2>/dev/console) 2>&1

trap 'echo "[ERROR] user-data failed at line ${LINENO}" >&2' ERR

export DEBIAN_FRONTEND=noninteractive

echo "[INFO] user-data launcher starting"

apt-get -o DPkg::Lock::Timeout=60 update
apt-get -o DPkg::Lock::Timeout=60 install -y \
  ca-certificates \
  curl \
  git \
  gnupg \
  lsb-release \
  sudo

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  echo "[INFO] cloning bootstrap repository"
  rm -rf "${REPO_DIR}"
  git clone --branch "${REPO_BRANCH}" "${REPO_URL}" "${REPO_DIR}"
else
  echo "[INFO] updating existing bootstrap repository"
  cd "${REPO_DIR}"
  git fetch origin "${REPO_BRANCH}"
  git reset --hard "origin/${REPO_BRANCH}"
fi

cd "${REPO_DIR}"

chmod +x bootstrap/bootstrap.sh
chmod +x bootstrap/stages/*.sh
chmod +x scripts/*.sh
chmod +x bootstrap/verify/*.sh

echo "[INFO] running bootstrap"
bash bootstrap/bootstrap.sh

echo "[INFO] user-data launcher completed"

#!/bin/bash
set -Eeuo pipefail

cat <<'EOF'
#!/bin/bash
set -Eeuo pipefail

LOG_FILE="/var/log/user-data.log"
REPO_DIR="/home/ubuntu/arm64-bootstrap"
REPO_URL="https://github.com/charsme/arm64-bootstrap.git"
REPO_BRANCH="main"

exec > >(tee -a "${LOG_FILE}" | logger -t user-data -s 2>/dev/console) 2>&1

trap 'echo "[ERROR] user-data failed at line ${LINENO}" >&2' ERR

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl git gnupg lsb-release sudo

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  rm -rf "${REPO_DIR}"
  git clone --branch "${REPO_BRANCH}" "${REPO_URL}" "${REPO_DIR}"
else
  cd "${REPO_DIR}"
  git fetch origin "${REPO_BRANCH}"
  git reset --hard "origin/${REPO_BRANCH}"
fi

cd "${REPO_DIR}"
chmod +x bootstrap/bootstrap.sh
chmod +x bootstrap/stages/*.sh
chmod +x scripts/*.sh
chmod +x bootstrap/verify/*.sh

bash bootstrap/bootstrap.sh
EOF

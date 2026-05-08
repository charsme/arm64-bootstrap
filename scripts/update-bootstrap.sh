#!/bin/bash
set -Eeuo pipefail

REPO_DIR="${REPO_DIR:-/home/ubuntu/arm64-bootstrap}"
BRANCH="${BRANCH:-main}"

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  echo "bootstrap repository not found: ${REPO_DIR}" >&2
  exit 1
fi

cd "${REPO_DIR}"

git fetch origin "${BRANCH}"
git reset --hard "origin/${BRANCH}"

chmod +x bootstrap/bootstrap.sh
chmod +x bootstrap/stages/*.sh
chmod +x scripts/*.sh
chmod +x bootstrap/verify/*.sh

echo "bootstrap repository updated to origin/${BRANCH}"

#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=../bootstrap.env
source "${SCRIPT_DIR}/../bootstrap.env"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/logging.sh"

# AWS CLI v2 is not packaged in the Ubuntu arm64 apt repo; install the
# official zip bundle, pinned to AWSCLI_VERSION for reproducible AMIs.
# The bundle is GPG-verified against AWS's published signing key (committed
# at config/awscli/aws-cli-public-key.asc) before install, so a tampered or
# truncated download fails hard instead of installing.
# `./aws/install --update` is idempotent: it installs on first run and
# updates the existing install in place on reruns.

AWSCLI_KEY="${SCRIPT_DIR}/../config/awscli/aws-cli-public-key.asc"
BASE_URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64-${AWSCLI_VERSION}.zip"

ARCH="$(dpkg --print-architecture)"
[[ "${ARCH}" == "arm64" ]] || fatal "stage 17 expects arm64, got ${ARCH}"

[[ -f "${AWSCLI_KEY}" ]] || fatal "aws cli signing key missing: ${AWSCLI_KEY}"

log_info "installing aws cli v2 ${AWSCLI_VERSION}"

WORK_DIR="$(mktemp -d)"
# Isolated keyring so the import never touches the host's root GPG state.
GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
trap 'rm -rf "${WORK_DIR}" "${GNUPGHOME}"' EXIT

gpg --quiet --import "${AWSCLI_KEY}"

curl -fsSL "${BASE_URL}" -o "${WORK_DIR}/awscliv2.zip"
curl -fsSL "${BASE_URL}.sig" -o "${WORK_DIR}/awscliv2.zip.sig"

# Exit non-zero on a bad/missing signature; under `set -e` this aborts the run.
gpg --verify "${WORK_DIR}/awscliv2.zip.sig" "${WORK_DIR}/awscliv2.zip" \
  || fatal "aws cli signature verification failed"

unzip -q "${WORK_DIR}/awscliv2.zip" -d "${WORK_DIR}"

"${WORK_DIR}/aws/install" --update

log_info "aws cli installed and signature-verified"

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
# `./aws/install --update` is idempotent: it installs on first run and
# updates the existing install in place on reruns.

ARCH="$(dpkg --print-architecture)"
[[ "${ARCH}" == "arm64" ]] || fatal "stage 17 expects arm64, got ${ARCH}"

log_info "installing aws cli v2 ${AWSCLI_VERSION}"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

curl -fsSL \
  "https://awscli.amazonaws.com/awscli-exe-linux-aarch64-${AWSCLI_VERSION}.zip" \
  -o "${WORK_DIR}/awscliv2.zip"

unzip -q "${WORK_DIR}/awscliv2.zip" -d "${WORK_DIR}"

"${WORK_DIR}/aws/install" --update

log_info "aws cli installed"

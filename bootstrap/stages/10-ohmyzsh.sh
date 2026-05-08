#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../lib/logging.sh"

if [[ ! -d /home/ubuntu/.oh-my-zsh ]]; then
  log_info "installing oh-my-zsh"

  # shellcheck disable=SC2312
  sudo -u ubuntu RUNZSH=no CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

chsh -s /usr/bin/zsh ubuntu

cat >/home/ubuntu/.zshrc <<'EOF'
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git docker)

source $ZSH/oh-my-zsh.sh

export EDITOR=vim
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
EOF

chown ubuntu:ubuntu /home/ubuntu/.zshrc

log_info "oh-my-zsh configured"

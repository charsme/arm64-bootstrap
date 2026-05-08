#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../lib/logging.sh"

PACKAGES=(
  apt-transport-https
  ca-certificates
  curl
  git
  gnupg
  htop
  jq
  lsb-release
  net-tools
  tree
  unzip
  vim
  zsh
  rsync
  tmux
  ncdu
  btop
  iotop
  iftop
  dnsutils
  software-properties-common
  build-essential
  python3
  python3-pip
  uidmap
  dbus-user-session
  systemd-timesyncd
  unattended-upgrades
  zram-tools
)

log_info "installing base packages"

apt-get install -y "${PACKAGES[@]}"

timedatectl set-timezone UTC

systemctl enable systemd-timesyncd
systemctl restart systemd-timesyncd

git config --system init.defaultBranch main
git config --system core.editor vim

log_info "base packages installed"

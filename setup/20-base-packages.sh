#!/usr/bin/env bash
# 20-base-packages.sh - CLI tools expected on every machine. Idempotent.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

log "apt update"
$SUDO apt-get update

log "base packages"
$SUDO apt-get install -y \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    stow \
    htop \
    tmux \
    build-essential

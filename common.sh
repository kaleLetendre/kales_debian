#!/usr/bin/env bash
# common.sh - runs on every machine. Idempotent.
# Add packages and config that should exist on any Debian 13 XFCE install.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

log "apt update"
$SUDO apt-get update

# Base CLI tools expected everywhere.
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

# Add more sections below as the environment grows.
# Group additions by purpose with a short comment explaining why.

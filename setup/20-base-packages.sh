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
# python3 ships by default on Debian, but `venv` and `pip` are split into
# separate packages -- without them, `python3 -m venv` produces a broken
# venv with no pip inside. Both are needed for any project that bootstraps
# itself into a venv (e.g. ./install.sh scripts that pip install -r ...).
$SUDO apt-get install -y \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    stow \
    htop \
    tmux \
    build-essential \
    postgresql-client \
    python3-venv \
    python3-pip

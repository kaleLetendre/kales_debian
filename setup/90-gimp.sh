#!/usr/bin/env bash
# 90-gimp.sh - GIMP image editor from the Debian repos. Idempotent.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

if ! dpkg -s gimp >/dev/null 2>&1; then
    log "installing gimp"
    $SUDO apt-get install -y gimp
else
    log "gimp already installed"
fi

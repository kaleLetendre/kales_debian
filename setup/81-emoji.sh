#!/usr/bin/env bash
# 81-emoji.sh - install Noto Color Emoji (Google/Android emoji set) so
# emoji render in color instead of falling back to Symbola's monochrome
# outlines. The fonts-noto-color-emoji package's postinst registers
# itself as the preferred emoji font via fontconfig, so an install +
# fc-cache refresh is all that's needed. Idempotent.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

if ! dpkg -s fonts-noto-color-emoji >/dev/null 2>&1; then
    log "installing fonts-noto-color-emoji"
    $SUDO apt-get install -y fonts-noto-color-emoji
    log "refreshing font cache"
    fc-cache -f >/dev/null
else
    log "fonts-noto-color-emoji already installed"
fi

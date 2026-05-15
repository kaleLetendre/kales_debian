#!/usr/bin/env bash
# 60-terminal.sh - xfce4-terminal preferences. Idempotent.
#
# Disables the "unsafe paste" confirmation dialog that triggers on any
# paste containing newlines or shell control characters.
#
# Note: xfce4-terminal runs a single daemon process and reads terminalrc
# only at process start. This change takes effect after a reboot (or after
# fully exiting xfce4-terminal -- `xfce4-terminal --quit`).

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

# crudini is the right tool for idempotent INI section/key edits without
# clobbering other keys. Installed locally because this module is the
# only consumer so far.
if ! command -v crudini >/dev/null 2>&1; then
    log "installing crudini"
    $SUDO apt-get install -y crudini
fi

CONF="$HOME/.config/xfce4/terminal/terminalrc"
mkdir -p "$(dirname "$CONF")"
touch "$CONF"

log "setting MiscShowUnsafePasteDialog=FALSE in $CONF"
crudini --set "$CONF" Configuration MiscShowUnsafePasteDialog FALSE

#!/usr/bin/env bash
# 60-terminal.sh - install kitty and make it the system terminal. Idempotent.
#
# We tried theming xfce4-terminal here first; on Xfce 4.20 (Debian 13's
# xfce4-terminal 1.1.4) ColorUseTheme=FALSE + an explicit ColorPalette in
# terminalrc gets silently ignored, the GTK theme wins, and the palette
# never applies. Rather than fight that, the whole machine moves to kitty:
# GPU-accelerated, themed by a plain text config in dotfiles/kitty/, and
# actively maintained.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

# kitty ships in Debian main. The metapackage pulls in terminfo + icon.
log "installing kitty"
$SUDO apt-get install -y kitty kitty-terminfo

# Make kitty the answer to /usr/bin/x-terminal-emulator, which is what
# Debian-aware tools (sensible-terminal, xdg-open helpers, some scripts)
# launch when they want "a terminal". The kitty package registers itself
# as an alternative on install, so --set just picks it.
if [[ -x /usr/bin/kitty ]]; then
    log "setting kitty as x-terminal-emulator"
    $SUDO update-alternatives --set x-terminal-emulator /usr/bin/kitty
fi

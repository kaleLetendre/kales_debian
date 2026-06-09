#!/usr/bin/env bash
# 60-terminal.sh - xfce4-terminal preferences. Idempotent.
#
# Disables the "unsafe paste" confirmation dialog that triggers on any
# paste containing newlines or shell control characters.
#
# Note: xfce4-terminal runs a single daemon process and reads terminalrc
# only at process start. Changes take effect after a reboot or after
# `pkill xfce4-terminal` (closes every open window, so save first).

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

# Sweet-Dark palette, hand-rolled from ~/.themes/Sweet-Dark/gtk-3.0/gtk-dark.css
# to match the GTK/xfwm4 theme set in setup/40-themes.sh. Every slot is a
# real Sweet color except yellow (Sweet has none, so this is a desaturated
# gold that doesn't clash with the cool palette) and the "normal" green/cyan
# (synthesized darker variants of Sweet's bright mint/cyan so bold/bright
# stands out from non-bold).
#
# ANSI 0-7  normal   black red green yellow blue magenta cyan white
# ANSI 8-15 bright   same order, brighter
log "applying Sweet-Dark palette in $CONF"
# ColorUseTheme=FALSE: without this xfce4-terminal silently pulls fg/bg/palette
# from the GTK theme and ignores everything below. Same idea for the cursor
# and selection "UseDefault" flags -- they have to be FALSE for our explicit
# ColorCursor / ColorSelectionBackground to actually take effect.
crudini --set "$CONF" Configuration ColorUseTheme            FALSE
crudini --set "$CONF" Configuration ColorCursorUseDefault    FALSE
crudini --set "$CONF" Configuration ColorSelectionUseDefault FALSE
crudini --set "$CONF" Configuration ColorForeground          '#C3C7D1'
crudini --set "$CONF" Configuration ColorBackground          '#161925'
crudini --set "$CONF" Configuration ColorCursor              '#c50ed2'
crudini --set "$CONF" Configuration ColorSelectionBackground '#333955'
crudini --set "$CONF" Configuration ColorPalette \
    '#181b28;#ce1138;#5dd989;#f5cf65;#6D44DE;#c50ed2;#00c1e4;#C3C7D1;#333955;#FF005B;#71f79f;#ffe082;#8500f7;#E948FF;#6bf7ff;#fefefe'

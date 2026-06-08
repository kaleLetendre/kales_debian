#!/usr/bin/env bash
# 76-app-hotkeys.sh - per-app launch hotkeys via xfce4-keyboard-shortcuts.
# Idempotent.
#
# Pattern matches the existing default bindings:
#   <Super>e -> thunar, <Super>r -> xfce4-appfinder -c, ...

set -euo pipefail

log() { printf "  -> %s\n" "$*"; }

# key | command
# Note: xfsettingsd runs the command via g_spawn_command_line_async, which
# splits on whitespace but does NOT do shell expansion -- wrap in bash -c
# when you need $HOME / globs / etc.
BINDINGS=(
    "<Super>c|galculator"
    "<Super>e|code"
    "<Super>n|mousepad"
    "<Super>v|vivaldi"
    "<Super>f|bash -c 'thunar \"\$HOME\"'"
    # CopyQ clipboard window. Overrides XFCE's default Super+P
    # (xfce4-display-settings --minimal); we don't reach for that often.
    # Under the i3 session a `for_window` rule floats + centers it
    # (dotfiles/i3/.config/i3/config); under xfwm4 it opens as a normal
    # window. `toggle` opens/closes the main UI; `menu` would pop at the
    # cursor instead, but cursor-anchored felt wrong.
    "<Super>p|copyq toggle"
)

if ! command -v xfconf-query >/dev/null 2>&1; then
    log "xfconf-query not found (XFCE not installed?); skipping"
    exit 0
fi

for entry in "${BINDINGS[@]}"; do
    key="${entry%%|*}"
    cmd="${entry##*|}"
    prop="/commands/custom/$key"

    current="$(xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" 2>/dev/null || true)"
    if [[ "$current" == "$cmd" ]]; then
        log "$key already bound to $cmd"
        continue
    fi
    log "binding $key -> $cmd"
    xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" \
        --create --type string --set "$cmd"
done

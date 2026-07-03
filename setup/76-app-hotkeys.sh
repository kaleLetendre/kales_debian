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
    # Screen lock. XFCE's default Ctrl+Alt+L runs xflock4, which locks fine
    # under xfwm4 but NOT in the i3 session: xflock4's primary path is a D-Bus
    # Lock to org.xfce.SessionManager, and the i3 session doesn't run
    # xfce4-session (see 87-i3.sh), so it falls through to light-locker and
    # silently no-ops. Crucially, in the i3 session xfsettingsd -- not i3 --
    # owns these shortcut grabs (it starts first and wins the grab), so fixing
    # i3's own config can't help; the command has to change HERE.
    #
    # We point it at the stowed lock.sh, which runs i3lock-color (blur + clock,
    # built by 99-i3lock-color.sh) and falls back to vanilla i3lock when the
    # fork isn't installed. bash -c so $HOME expands at run time (xfsettingsd
    # does no shell expansion of its own) -- same trick as the thunar bind.
    "<Primary><Alt>l|bash -c '\$HOME/.config/i3/lock.sh'"
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

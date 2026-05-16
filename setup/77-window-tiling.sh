#!/usr/bin/env bash
# 77-window-tiling.sh - Super+Shift+Arrow tile-to-half bindings so
# window tiling works on laptops without a numeric keypad. The existing
# Super+Numpad bindings (xfwm4 defaults) are left in place, so both
# keysets work on machines that have a numpad. Idempotent.
#
# Why Super+Shift+Arrow instead of plain Super+Arrow: on at least one
# XFCE 4.20 setup, xfwm4 silently failed to grab <Super>Right and
# <Super>Down at session start (Up/Left grabbed fine). The exact
# colliding client could not be isolated; Super+Shift+Arrow has no such
# conflict and grabs cleanly. Plain Alt+Arrow was avoided because it
# steals browser back/forward and word-jump in terminals.

set -euo pipefail

log() { printf "  -> %s\n" "$*"; }

# key | xfwm4 action
BINDINGS=(
    "<Super><Shift>Up|tile_up_key"
    "<Super><Shift>Down|tile_down_key"
    "<Super><Shift>Left|tile_left_key"
    "<Super><Shift>Right|tile_right_key"
)

if ! command -v xfconf-query >/dev/null 2>&1; then
    log "xfconf-query not found (XFCE not installed?); skipping"
    exit 0
fi

for entry in "${BINDINGS[@]}"; do
    key="${entry%%|*}"
    action="${entry##*|}"
    prop="/xfwm4/custom/$key"

    current="$(xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" 2>/dev/null || true)"
    if [[ "$current" == "$action" ]]; then
        log "$key already bound to $action"
        continue
    fi
    log "binding $key -> $action"
    xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" \
        --create --type string --set "$action"
done

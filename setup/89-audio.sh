#!/usr/bin/env bash
# 89-audio.sh - add the PulseAudio plugin to the top panel.
#
# xfce4-pulseaudio-plugin gives us BOTH the volume tray icon AND the
# XF86Audio* media-key handling (raise / lower / mute, plus mic mute
# and playback controls). The deprecated xfce4-volumed-pulse daemon is
# no longer in Debian repos -- since plugin v0.4 the plugin itself
# handles media keys, so adding it to the panel is the whole fix.
#
# Idempotent: skips if a pulseaudio plugin is already on any panel.
# Mirrors the placement logic from 79-battery-indicator.sh -- inserted
# right after the systray on panel-1, so it lives next to the
# power-manager / network icons.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

if ! command -v xfconf-query >/dev/null 2>&1; then
    log "xfconf-query not found (XFCE not installed?); skipping"
    exit 0
fi

if ! dpkg -s xfce4-pulseaudio-plugin >/dev/null 2>&1; then
    log "installing xfce4-pulseaudio-plugin"
    $SUDO apt-get install -y xfce4-pulseaudio-plugin
fi

# Bail out early if a pulseaudio plugin is already on any panel.
for plugin_path in $(xfconf-query -c xfce4-panel -l 2>/dev/null | grep -E '^/plugins/plugin-[0-9]+$'); do
    type="$(xfconf-query -c xfce4-panel -p "$plugin_path" 2>/dev/null || true)"
    if [[ "$type" == "pulseaudio" ]]; then
        log "$plugin_path already exists; skipping"
        exit 0
    fi
done

# Next free plugin id = max(existing) + 1.
max_id="$(xfconf-query -c xfce4-panel -l 2>/dev/null \
    | awk -F- '/^\/plugins\/plugin-[0-9]+$/ { print $NF }' \
    | sort -un | tail -1)"
max_id="${max_id:-0}"
new_id=$((max_id + 1))

log "registering plugin-$new_id (pulseaudio)"
xfconf-query -c xfce4-panel -p "/plugins/plugin-$new_id" \
    --create --type string --set "pulseaudio"

# Sensible defaults: enable keyboard shortcuts (the whole point) and
# show notifications on volume change so there's visual feedback for
# the key press.
xfconf-query -c xfce4-panel -p "/plugins/plugin-$new_id/enable-keyboard-shortcuts" \
    --create --type bool --set true
xfconf-query -c xfce4-panel -p "/plugins/plugin-$new_id/show-notifications" \
    --create --type bool --set true

# Insert into panel-1 right after the systray (mirrors 79's placement).
mapfile -t panel1_ids < <(
    xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids 2>/dev/null \
        | awk '/^[0-9]+$/'
)

systray_idx=-1
for i in "${!panel1_ids[@]}"; do
    pid="${panel1_ids[$i]}"
    type="$(xfconf-query -c xfce4-panel -p "/plugins/plugin-$pid" 2>/dev/null || true)"
    [[ "$type" == "systray" ]] && systray_idx=$i && break
done

if (( systray_idx >= 0 )); then
    before=("${panel1_ids[@]:0:$((systray_idx+1))}")
    after=("${panel1_ids[@]:$((systray_idx+1))}")
    final=("${before[@]}" "$new_id" "${after[@]}")
else
    final=("${panel1_ids[@]}" "$new_id")
fi

log "panel-1 plugin-ids: ${final[*]}"
args=()
for id in "${final[@]}"; do
    args+=(--type int --set "$id")
done
xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids \
    --create --force-array "${args[@]}"

log "config written; run 'xfce4-panel -r' or reboot to apply"

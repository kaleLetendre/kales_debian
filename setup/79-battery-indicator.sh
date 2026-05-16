#!/usr/bin/env bash
# 79-battery-indicator.sh - add a battery indicator to the top panel
# (panel-1), positioned in the right cluster next to the clock. Shows
# percentage on the label and charging state via the icon. Idempotent:
# skips if a power-manager-plugin already exists on any panel.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

if ! command -v xfconf-query >/dev/null 2>&1; then
    log "xfconf-query not found (XFCE not installed?); skipping"
    exit 0
fi

# Skip on machines with no battery (desktops, servers).
if ! ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
    log "no battery detected; skipping"
    exit 0
fi

if ! dpkg -s xfce4-power-manager-plugins >/dev/null 2>&1; then
    log "installing xfce4-power-manager-plugins"
    $SUDO apt-get install -y xfce4-power-manager-plugins
fi

# Bail out early if a power-manager-plugin is already on any panel.
for plugin_path in $(xfconf-query -c xfce4-panel -l 2>/dev/null | grep -E '^/plugins/plugin-[0-9]+$'); do
    type="$(xfconf-query -c xfce4-panel -p "$plugin_path" 2>/dev/null || true)"
    if [[ "$type" == "power-manager-plugin" ]]; then
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

log "registering plugin-$new_id (power-manager-plugin)"
xfconf-query -c xfce4-panel -p "/plugins/plugin-$new_id" \
    --create --type string --set "power-manager-plugin"

# show-panel-label: 0=hide, 1=percentage, 2=time, 3=both. We want percentage.
xfconf-query -c xfce4-panel -p "/plugins/plugin-$new_id/show-panel-label" \
    --create --type int --set 1

# Insert into panel-1 right after the systray plugin (which is the last
# item in the "right cluster" before the trailing separator + clock).
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
    # No systray on panel-1; just append.
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

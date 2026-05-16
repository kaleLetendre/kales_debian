#!/usr/bin/env bash
# 74-panel-launchers.sh - add VS Code, DBeaver, Postman, and Vivaldi
# launchers to the bottom XFCE panel (panel-2). Idempotent: skips apps
# whose .desktop file is already referenced by any existing launcher.
#
# Panel-2 layout (left to right):
#   showdesktop | separator | [launchers] | separator | directorymenu
# New launchers are inserted directly after the last existing launcher,
# so they sit with the rest of the dock items.
#
# Takes effect after `xfce4-panel -r` or the reboot prompted at the end
# of bootstrap. No daemon restart here -- same reasoning as 60-terminal.sh.

set -euo pipefail

log() { printf "  -> %s\n" "$*"; }

APPS=(
    "code.desktop"
    "dbeaver-ce.desktop"
    "postman.desktop"
    "vivaldi-stable.desktop"
)

if ! command -v xfconf-query >/dev/null 2>&1; then
    log "xfconf-query not found (XFCE not installed?); skipping"
    exit 0
fi

# Collect every .desktop file currently referenced by any launcher plugin
# (across both panels), so re-runs don't add duplicates and so launchers
# the user has dragged to the other panel are still detected.
existing_items=()
while IFS= read -r plugin_path; do
    type="$(xfconf-query -c xfce4-panel -p "$plugin_path" 2>/dev/null || true)"
    [[ "$type" == "launcher" ]] || continue
    while IFS= read -r item; do
        [[ "$item" =~ ^[A-Za-z0-9._+-]+\.desktop$ ]] && existing_items+=("$item")
    done < <(xfconf-query -c xfce4-panel -p "$plugin_path/items" 2>/dev/null || true)
done < <(xfconf-query -c xfce4-panel -l 2>/dev/null | grep -E '^/plugins/plugin-[0-9]+$')

is_present() {
    local needle="$1"
    for ex in "${existing_items[@]}"; do
        [[ "$ex" == "$needle" ]] && return 0
    done
    return 1
}

# Next free plugin id = max(existing) + 1, allocated as we go.
max_id="$(xfconf-query -c xfce4-panel -l 2>/dev/null \
    | awk -F- '/^\/plugins\/plugin-[0-9]+$/ { print $NF }' \
    | sort -un | tail -1)"
max_id="${max_id:-0}"

new_ids=()

for desktop in "${APPS[@]}"; do
    if is_present "$desktop"; then
        log "$desktop already in a launcher; skipping"
        continue
    fi
    src="/usr/share/applications/$desktop"
    if [[ ! -f "$src" ]]; then
        log "$src not installed; skipping (earlier setup module should install it)"
        continue
    fi

    max_id=$((max_id + 1))
    log "adding $desktop as plugin-$max_id"

    launcher_dir="$HOME/.config/xfce4/panel/launcher-$max_id"
    mkdir -p "$launcher_dir"
    cp "$src" "$launcher_dir/$desktop"

    xfconf-query -c xfce4-panel -p "/plugins/plugin-$max_id" \
        --create --type string --set "launcher"
    xfconf-query -c xfce4-panel -p "/plugins/plugin-$max_id/items" \
        --create --force-array --type string --set "$desktop"

    new_ids+=("$max_id")
done

if (( ${#new_ids[@]} == 0 )); then
    log "nothing to add"
    exit 0
fi

# Current panel-2 plugin-ids, one per line.
mapfile -t panel2_ids < <(
    xfconf-query -c xfce4-panel -p /panels/panel-2/plugin-ids 2>/dev/null \
        | awk '/^[0-9]+$/'
)

# Insert new ids after the last existing launcher in the array, so the
# new dock items group with the others (and stay before the trailing
# separator + directorymenu).
last_idx=-1
for i in "${!panel2_ids[@]}"; do
    pid="${panel2_ids[$i]}"
    type="$(xfconf-query -c xfce4-panel -p "/plugins/plugin-$pid" 2>/dev/null || true)"
    [[ "$type" == "launcher" ]] && last_idx=$i
done

if (( last_idx >= 0 )); then
    before=("${panel2_ids[@]:0:$((last_idx+1))}")
    after=("${panel2_ids[@]:$((last_idx+1))}")
    final=("${before[@]}" "${new_ids[@]}" "${after[@]}")
else
    final=("${panel2_ids[@]}" "${new_ids[@]}")
fi

log "panel-2 plugin-ids: ${final[*]}"
args=()
for id in "${final[@]}"; do
    args+=(--type int --set "$id")
done
xfconf-query -c xfce4-panel -p /panels/panel-2/plugin-ids \
    --create --force-array "${args[@]}"

log "config written; run 'xfce4-panel -r' or reboot to apply"

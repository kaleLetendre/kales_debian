#!/usr/bin/env bash
# 80-home-dirs.sh - create the workspace folders under $HOME, plus the
# standard XDG user dirs (Downloads, Documents, Pictures, ...). Also
# pins ~/.config/user-dirs.dirs to canonical paths. Idempotent.
#
# Why not just `xdg-user-dirs-update`: that tool only rewrites the
# config file, it does NOT create missing directories. Worse: if a
# configured dir was deleted, it "helpfully" reassigns the XDG slot to
# $HOME itself, which means browsers, screenshot tools, etc. then dump
# files directly into $HOME. We bypass it and manage the file ourselves.

set -euo pipefail

log() { printf "  -> %s\n" "$*"; }

WORKSPACES=(
    "$HOME/personal"
    "$HOME/caracal"
)

# Standard XDG user dirs. Names match what XFCE / browsers / etc.
# expect at $HOME/<name>.
XDG_DIRS=(
    "Desktop"
    "Downloads"
    "Documents"
    "Pictures"
    "Music"
    "Videos"
    "Templates"
    "Public"
)

for d in "${WORKSPACES[@]}" "${XDG_DIRS[@]/#/$HOME/}"; do
    if [[ -d "$d" ]]; then
        log "$d already exists"
    else
        log "creating $d"
        mkdir -p "$d"
    fi
done

# Pin the XDG config so apps look in $HOME/<name>, not somewhere stale.
CFG="$HOME/.config/user-dirs.dirs"
read -r -d '' CFG_BODY <<'EOF' || true
# Managed by kales_debian/setup/80-home-dirs.sh. Edit there, not here.
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
EOF

mkdir -p "$(dirname "$CFG")"
if [[ -f "$CFG" ]] && diff -q <(printf '%s\n' "$CFG_BODY") "$CFG" >/dev/null 2>&1; then
    log "$CFG already current"
else
    log "writing $CFG"
    printf '%s\n' "$CFG_BODY" > "$CFG"
fi

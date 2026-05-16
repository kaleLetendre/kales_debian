#!/usr/bin/env bash
# 80-home-dirs.sh - scaffold "workspace" directories under $HOME, each
# with a fixed set of subdirs. Layout is declarative in
# setup/home-layout.json:
#
#   { "workspaces": ["personal", "caracal"],
#     "subdirs":    ["repos", "documents"] }
#
# A workspace is a top-level parent folder for everything related to a
# project or workplace. Subdirs are the same for every workspace. To add
# or rename a workspace, edit home-layout.json -- no script change needed.
#
# Idempotent.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYOUT="$SCRIPT_DIR/home-layout.json"

if [[ ! -f "$LAYOUT" ]]; then
    echo "$LAYOUT not found" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    log "installing jq"
    $SUDO apt-get install -y jq
fi

mapfile -t workspaces < <(jq -r '.workspaces[]' "$LAYOUT")
mapfile -t subdirs    < <(jq -r '.subdirs[]'    "$LAYOUT")

for ws in "${workspaces[@]}"; do
    for sd in "${subdirs[@]}"; do
        d="$HOME/$ws/$sd"
        if [[ -d "$d" ]]; then
            log "$d already exists"
        else
            log "creating $d"
            mkdir -p "$d"
        fi
    done
done

#!/usr/bin/env bash
# 80-home-dirs.sh - create personal directories under $HOME. Idempotent.

set -euo pipefail

log() { printf "  -> %s\n" "$*"; }

DIRS=(
    "$HOME/personal"
    "$HOME/caracal"
)

for d in "${DIRS[@]}"; do
    if [[ -d "$d" ]]; then
        log "$d already exists"
    else
        log "creating $d"
        mkdir -p "$d"
    fi
done

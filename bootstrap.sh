#!/usr/bin/env bash
# bootstrap.sh - one-command setup for a fresh Debian 13 XFCE install.
# Idempotent: safe to re-run after any change.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

log() { printf "\n== %s ==\n" "$*"; }

log "bootstrap starting"
echo "Repo: $REPO_DIR"
echo "Host: $(hostname)"

# Common layer (runs on every machine).
log "common.sh"
bash "$REPO_DIR/common.sh"

# Hardware-specific layer, picked by DMI product name.
# /sys/class/dmi/id/product_name is readable without root and needs no extra package.
PRODUCT="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
MACHINE=""
case "$PRODUCT" in
    *"Precision 3591"*) MACHINE="precision-3591" ;;
esac

if [[ -n "$MACHINE" && -f "$REPO_DIR/hardware/$MACHINE.sh" ]]; then
    log "hardware: $MACHINE"
    bash "$REPO_DIR/hardware/$MACHINE.sh"
else
    log "hardware: no specific profile (product='$PRODUCT')"
fi

# Dotfiles via stow. Each subdir of dotfiles/ is a stow package.
if command -v stow >/dev/null 2>&1 && [[ -d "$REPO_DIR/dotfiles" ]]; then
    shopt -s nullglob
    pkgs=("$REPO_DIR/dotfiles"/*/)
    if (( ${#pkgs[@]} > 0 )); then
        log "dotfiles: stowing"
        cd "$REPO_DIR/dotfiles"
        for p in */; do
            stow -t "$HOME" -R "${p%/}"
        done
    fi
fi

log "bootstrap done"

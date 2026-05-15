#!/usr/bin/env bash
# bootstrap.sh - one-command setup for a fresh Debian 13 XFCE install.
# Idempotent: safe to re-run any time.
#
# Layout:
#   setup/NN-thing.sh   - one concern per file, run in lex order on every
#                         machine. Add a new file to add a new concern.
#   hardware/<name>.sh  - runs only when the DMI product name matches.
#   dotfiles/<pkg>/...  - stow packages, symlinked into $HOME at the end.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

log() { printf "\n== %s ==\n" "$*"; }

log "bootstrap starting"
echo "Repo: $REPO_DIR"
echo "Host: $(hostname)"

# Setup modules. Numbered prefix controls order. Each must be idempotent.
if [[ -d "$REPO_DIR/setup" ]]; then
    shopt -s nullglob
    for module in "$REPO_DIR/setup"/*.sh; do
        log "$(basename "$module")"
        bash "$module"
    done
    shopt -u nullglob
fi

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
echo
echo "Reboot recommended: some changes (e.g. xfce4-terminal settings,"
echo "group memberships, kernel/driver updates) only take effect after a"
echo "fresh login or full restart."
echo
read -r -p "Reboot now? [y/N] " ans
if [[ "${ans,,}" == y* ]]; then
    sudo systemctl reboot
fi

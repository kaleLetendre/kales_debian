#!/usr/bin/env bash
# 62-freecad.sh - FreeCAD parametric 3D CAD from the Debian repos, plus the
# maintained "Gears" workbench (looooo/freecad.gears) cloned into the user's
# FreeCAD Mod directory. Idempotent.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

# --- FreeCAD itself (Debian repo package; Trixie ships 1.0.0) ---
if ! dpkg -s freecad >/dev/null 2>&1; then
    log "installing freecad"
    $SUDO apt-get install -y freecad
else
    log "freecad already installed"
fi

# --- Gears workbench (looooo/freecad.gears, shown as "Gears" in FreeCAD) ---
# Installed the way the in-app Addon Manager does it: the addon lives as a
# subdir of FreeCAD's per-user Mod directory, which FreeCAD 1.0 scans at
# startup. This is a user-level file drop in $HOME, so no sudo here.
MOD_DIR="$HOME/.local/share/FreeCAD/Mod"
GEARS_DIR="$MOD_DIR/freecad.gears"
GEARS_REPO="https://github.com/looooo/freecad.gears"

mkdir -p "$MOD_DIR"
if [[ -d "$GEARS_DIR/.git" ]]; then
    # Already cloned: fast-forward to upstream so re-runs stay current.
    log "gears workbench present, updating"
    git -C "$GEARS_DIR" pull --ff-only
else
    log "cloning gears workbench"
    git clone "$GEARS_REPO" "$GEARS_DIR"
fi

#!/usr/bin/env bash
# 82-calculator.sh - install galculator. Idempotent.
#
# Lightweight GTK calculator, paired with the Super+C hotkey set in
# 76-app-hotkeys.sh. Chosen over gnome-calculator (drags in GNOME libs)
# and qalculate-gtk (overkill for quick arithmetic).

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

log "installing galculator"
$SUDO apt-get install -y galculator

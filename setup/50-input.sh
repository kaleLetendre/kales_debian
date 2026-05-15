#!/usr/bin/env bash
# 50-input.sh - touchpad behavior: tap-to-click + natural scrolling.
# Idempotent.
#
# Two paths so the change takes effect now AND on every future X session:
#   1. /etc/X11/xorg.conf.d/40-libinput-touchpad.conf - machine-agnostic
#      xorg snippet matched by libinput driver + IsTouchpad, applied at
#      X session start.
#   2. xinput set-prop - best-effort live apply on the running session so
#      no logout/login needed after a fresh bootstrap.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

# Need xinput for the live-apply step. Localized here so the dep belongs
# to the module that uses it.
if ! command -v xinput >/dev/null 2>&1; then
    log "installing xinput"
    $SUDO apt-get install -y xinput
fi

CONF_PATH="/etc/X11/xorg.conf.d/40-libinput-touchpad.conf"
read -r -d '' CONF_BODY <<'EOF' || true
# Managed by kales_debian/setup/50-input.sh. Edit there, not here.
Section "InputClass"
    Identifier "libinput touchpad config"
    MatchIsTouchpad "on"
    MatchDriver "libinput"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
EndSection
EOF

# 1. Persistent xorg snippet. Compare-and-write so identical re-runs do
#    nothing.
need_write=1
if [[ -f "$CONF_PATH" ]] && diff -q <(printf '%s\n' "$CONF_BODY") "$CONF_PATH" >/dev/null 2>&1; then
    need_write=0
fi
if (( need_write )); then
    log "writing $CONF_PATH"
    $SUDO install -d -m 0755 "$(dirname "$CONF_PATH")"
    printf '%s\n' "$CONF_BODY" | $SUDO tee "$CONF_PATH" >/dev/null
else
    log "$CONF_PATH already current"
fi

# 2. Live apply for the current X session, if there is one. Touchpad device
#    name varies per machine; discover via xinput. Property names are
#    libinput's standard ones, present on any libinput-managed touchpad.
if command -v xinput >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    # Find the first device whose name contains "touchpad" (case-insensitive).
    touchpad="$(xinput list --name-only 2>/dev/null | grep -i touchpad | head -n1 || true)"
    if [[ -n "$touchpad" ]]; then
        log "live-applying to '$touchpad'"
        xinput set-prop "$touchpad" "libinput Tapping Enabled" 1 2>/dev/null || true
        xinput set-prop "$touchpad" "libinput Natural Scrolling Enabled" 1 2>/dev/null || true
    else
        log "no touchpad found via xinput; settings will apply on next X session"
    fi
else
    log "no X session (or xinput missing); settings will apply on next X session"
fi

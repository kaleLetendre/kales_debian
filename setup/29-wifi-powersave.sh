#!/usr/bin/env bash
# 29-wifi-powersave.sh - disable Wi-Fi power saving. Idempotent.
#
# Why: with power save on, the Intel radio (iwlwifi/iwlmvm, e.g. the BE200 in
# the Precision 3591) parks itself between packets and takes hundreds of ms to
# wake. Signal reads full-strength, but latency to the *local gateway* balloons
# to ~1s with wild jitter -- which makes anything interactive over the link
# (SSH keystroke echo, Tailscale/mosh) feel broken. Seen in the wild: gateway
# RTT avg 931ms / max 1467ms with power save on, dropping to avg ~7ms the moment
# it's disabled. Same-region Tailscale hop went 423ms -> 32ms.
#
# Two independent knobs, because either alone leaves a gap:
#   1. NetworkManager default (wifi.powersave = 2 -> disabled) governs every
#      connection whose profile leaves powersave at 0/"default", so we don't
#      have to edit each saved SSID (and SSID profiles carry the PSK anyway, so
#      they can't live in this repo).
#   2. iwlwifi/iwlmvm module options pin the driver itself awake (power_scheme=1
#      = CAM, continuously awake). Belt-and-suspenders below the NM layer.
#
# Vendor-neutral at the NM layer (harmless on non-Intel Wi-Fi); the modprobe
# options are Intel-only but inert if iwlwifi isn't the driver -- so this is a
# setup/ module, not hardware/precision-3591.sh.

set -euo pipefail

SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

# 1. NetworkManager global default: disable Wi-Fi power save for any connection
#    that doesn't explicitly override it. conf.d is read on top of NM's config,
#    so dropping one file is enough; harmless if NetworkManager isn't installed.
NM_CONF="/etc/NetworkManager/conf.d/wifi-powersave-off.conf"
NM_BODY=$'[connection]\nwifi.powersave = 2\n'   # 2 = disable (1=default/on, 0=use-default)

if [[ ! -f "$NM_CONF" ]] || ! diff -q <(printf '%s' "$NM_BODY") "$NM_CONF" >/dev/null 2>&1; then
    log "writing $NM_CONF (wifi.powersave = 2)"
    $SUDO install -d -m 0755 "$(dirname "$NM_CONF")"
    printf '%s' "$NM_BODY" | $SUDO tee "$NM_CONF" >/dev/null
    # Pick up the new default without dropping the current link where possible.
    if command -v nmcli >/dev/null 2>&1; then
        $SUDO nmcli general reload
    fi
else
    log "$NM_CONF already current"
fi

# 2. iwlwifi/iwlmvm driver options: keep the radio awake at the driver level.
#    Only takes effect on module (re)load -- i.e. next boot. We don't reload
#    iwlwifi here because that tears down the Wi-Fi mid-bootstrap.
MODPROBE_CONF="/etc/modprobe.d/iwlwifi-powersave.conf"
MODPROBE_BODY=$'options iwlwifi power_save=0\noptions iwlmvm power_scheme=1\n'

if [[ ! -f "$MODPROBE_CONF" ]] || ! diff -q <(printf '%s' "$MODPROBE_BODY") "$MODPROBE_CONF" >/dev/null 2>&1; then
    log "writing $MODPROBE_CONF (power_save=0, power_scheme=1) -- takes effect next boot"
    printf '%s' "$MODPROBE_BODY" | $SUDO tee "$MODPROBE_CONF" >/dev/null
else
    log "$MODPROBE_CONF already current"
fi

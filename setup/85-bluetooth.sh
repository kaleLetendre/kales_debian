#!/usr/bin/env bash
# 85-bluetooth.sh - Bluetooth stack + XFCE tray applet + A2DP audio +
# reconnect tuning.
#
# Debian XFCE doesn't ship a Bluetooth tray by default (unlike Ubuntu's
# XFCE seed). bluez is the actual stack and is usually already pulled
# in, but we list it explicitly so this script is self-contained.
# blueman is what's actually missing: it provides the panel applet,
# pairing wizard, and device manager dialog.
#
# blueman ships /etc/xdg/autostart/blueman.desktop, so on next XFCE
# login the tray icon appears on its own. For the current session,
# launch `blueman-applet &` once.

set -euo pipefail

log() { printf "  -> %s\n" "$*"; }

# Track whether PipeWire's Bluetooth backend is a fresh install, so we
# only bounce wireplumber when something actually changed.
spa_bluez5_was_missing=0
dpkg -s libspa-0.2-bluetooth >/dev/null 2>&1 || spa_bluez5_was_missing=1

# libspa-0.2-bluetooth is PipeWire's Bluetooth audio backend (the bluez5
# SPA plugin + A2DP/HFP codecs). Debian ships it separately and NOTHING
# depends on it -- pipewire installs perfectly happily without it, so a
# machine can look fully set up and still have zero Bluetooth audio.
#
# When it's missing the symptom looks like a radio or pairing problem and
# is not one: bluetoothd pairs and links a headset fine, but no A2DP/HFP
# endpoint is ever registered, so the headset finds no audio profile and
# hangs up after a few seconds. Presents as "won't connect, and drops the
# connection when it does". Re-pairing and moving closer change nothing.
#
# Diagnose with:  journalctl --user -u wireplumber | grep bluez5
#   "SPA handle 'api.bluez5.enum.dbus' could not be loaded" == this package.
# Confirm the fix with: pactl list cards short   (expect a bluez_card.* line
# once a headset is connected; the card only exists while connected).
#
# Pulls in libldacbt-abr2 as a dependency. Note that does NOT enable LDAC
# by itself -- encoding also needs libldacbt-enc2, deliberately left out:
# SBC-XQ is close enough on the WH-CH720N, and LDAC's higher bitrate makes
# dropouts *more* likely on the AX211's shared Wi-Fi/Bluetooth 2.4 GHz
# front end. Add enc2 only if you want to experiment.
sudo apt-get install -y bluez blueman libspa-0.2-bluetooth

# Bluetooth daemon. `enable --now` is idempotent: re-running on an
# already-active+enabled unit is a no-op.
sudo systemctl enable --now bluetooth.service

# Reliability tuning for BT input devices (the RK987A keyboard in
# particular hits all three of these). The keys ship commented-out in
# Debian's default main.conf, so we sed-flip them in place; the `^#*`
# guard matches either the commented default OR an already-active line,
# making the edit idempotent.
#
#   JustWorksRepairing = always
#     auto-accept re-pair when the device's stored bonding keys no
#     longer match. Without this, BT keyboards that reset their per-
#     slot keys end up "connected but not bonded" until you manually
#     remove + re-pair.
#   FastConnectable = true
#     shorter page-scan interval; the controller answers connect
#     requests faster (matters mostly for input devices waking from
#     sleep).
#   AutoEnable = true  (under [Policy])
#     bluetoothd re-powers the controller on service start. Without
#     this, a controller that was off at start stays off until a
#     manual `bluetoothctl power on`.
MAIN_CONF=/etc/bluetooth/main.conf
needs_edit=0
grep -q "^JustWorksRepairing = always$" "$MAIN_CONF" || needs_edit=1
grep -q "^FastConnectable = true$"      "$MAIN_CONF" || needs_edit=1
grep -q "^AutoEnable=true$"             "$MAIN_CONF" || needs_edit=1
if (( needs_edit )); then
    log "tuning $MAIN_CONF for keyboard reconnect reliability"
    sudo sed -i \
        -e 's/^#*JustWorksRepairing.*/JustWorksRepairing = always/' \
        -e 's/^#*FastConnectable.*/FastConnectable = true/' \
        -e 's/^#*AutoEnable=.*/AutoEnable=true/' \
        "$MAIN_CONF"
    log "restarting bluetooth.service to pick up config"
    sudo systemctl restart bluetooth.service
else
    log "$MAIN_CONF already tuned"
fi

# wireplumber only scans for SPA plugins at startup, so a freshly installed
# bluez5 backend is invisible to an already-running session -- Bluetooth
# audio stays broken until the next login. Bounce it here instead.
#
# Guarded twice: only when we actually installed the package, and only when
# there's a live user-session wireplumber to restart (a server-role or
# headless bootstrap has none, and `systemctl --user` would fail there).
if (( spa_bluez5_was_missing )); then
    if systemctl --user is-active --quiet wireplumber 2>/dev/null; then
        log "restarting wireplumber to load the bluez5 SPA plugin"
        systemctl --user restart wireplumber
    else
        log "bluez5 SPA plugin installed; takes effect on next login"
    fi
fi

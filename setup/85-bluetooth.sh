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

# Stop the kernel from USB-autosuspending the Intel Bluetooth radio.
#
# Second distinct A2DP failure mode after the bluez5-backend one above,
# and it looks nothing like a radio problem: audio plays fine, then the
# headset drops mid-stream and reconnects seconds later, over and over.
# The AX211 (USB id 8087:0033) ships with power/control=auto and a 2s
# autosuspend delay, so any brief idle gap (a pause, a silent passage)
# parks the USB interface; waking it starves the A2DP transport. The
# journal shows the exact chain:
#
#   wireplumber ... spa.audioconvert: out of buffers on port 0   (underrun)
#   wireplumber ... spa.bluez5.sink.media: error 24
#   wireplumber ... spa.bluez5: Failure in Bluetooth audio transport ...
#
# udev rule pins power/control=on for just this USB id, so it's a no-op
# on any machine without the AX211. TEST== guards the case where the
# power/ attributes aren't present yet. `on` = never autosuspend.
#
# Verify live (while a headset is connected):
#   cat /sys/bus/usb/devices/*/power/control   # the AX211's should read "on"
# runtime_suspended_time under that device's power/ should stop climbing.
BT_AUTOSUSPEND_RULE=/etc/udev/rules.d/81-bt-no-autosuspend.rules
if [[ ! -f "$BT_AUTOSUSPEND_RULE" ]]; then
    log "disabling USB autosuspend for the Intel BT radio (A2DP dropout fix)"
    sudo tee "$BT_AUTOSUSPEND_RULE" >/dev/null <<'EOF'
# Intel AX211 Bluetooth (8087:0033): USB autosuspend causes A2DP dropouts.
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0033", TEST=="power/control", ATTR{power/control}="on"
EOF
    # Reload rules and re-trigger so it applies without a reboot. Match by
    # the same vendor id; the trigger is a no-op if the radio isn't present.
    sudo udevadm control --reload-rules
    sudo udevadm trigger --subsystem-match=usb --attr-match=idVendor=8087
else
    log "$BT_AUTOSUSPEND_RULE already present"
fi

# --- A2DP dropouts every ~5 minutes: Wi-Fi roaming scans, NOT a BT fault ---
#
# Third distinct failure mode, and the sneakiest: audio drops for a second
# then recovers, on a near-perfect timer roughly every 5 minutes. Not
# autosuspend (power/control stays "on", runtime_suspended_time doesn't
# climb), not the bluez5 backend, not RF luck -- the metronomic period is
# the tell. The journal shows a bare transport failure with no underrun:
#
#   wireplumber ... spa.bluez5.sink.media: error 24
#   wireplumber ... spa.bluez5: Failure in Bluetooth audio transport ...
#   (then a reconnect ~15-40s later, and it repeats one scan-interval later)
#
# Cause: the AX211 shares ONE 2.4 GHz radio front end between Wi-Fi and
# Bluetooth. Even with Wi-Fi associated on 5 GHz, wpa_supplicant runs a
# background roaming scan (NetworkManager's default is roughly
# "simple:30:-70:300" -> a full sweep every 300s when signal is good) and
# that sweep visits the 2.4 GHz channels, briefly stealing the antenna and
# starving the A2DP transport. Worse signal -> 30s scans -> constant drops.
#
# This is NOT fixed here, on purpose: the only reliable NM-level lever is to
# pin the connection to its current BSSID (which stops the roam scan), and a
# BSSID is per-network/per-location -- it belongs in the NetworkManager
# connection profile (alongside the Wi-Fi PSK, i.e. outside this repo), not
# hardcoded into a module that runs on any machine. NM 1.52 exposes no
# per-connection bgscan knob to disable scanning generically.
#
# To apply on a machine that has this problem (replace the SSID; grab the
# BSSID you're on from the '*' row):
#
#   nmcli -f IN-USE,BSSID,SSID,CHAN device wifi list | grep '^\*'
#   nmcli connection modify <SSID> 802-11-wireless.bssid <BSSID>
#   nmcli connection up <SSID>
#
# Undo (restore roaming) with:
#   nmcli connection modify <SSID> -802-11-wireless.bssid
#
# Cost: the laptop stops roaming to other APs of the same SSID until undone,
# so it's the right call for a fixed desk, wrong for someone moving around.
# Confirm the fix by watching for `error 24` to stop recurring on the timer:
#   journalctl --user -u wireplumber -f | grep --line-buffered "error 24"

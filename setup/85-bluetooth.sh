#!/usr/bin/env bash
# 85-bluetooth.sh - Bluetooth stack + XFCE tray applet + reconnect tuning.
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

sudo apt-get install -y bluez blueman

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

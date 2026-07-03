#!/usr/bin/env bash
# 96-kdeconnect.sh - KDE Connect: phone <-> desktop integration over LAN
# (notifications, file/clipboard share, remote input, find-my-phone, etc).
# Idempotent.
#
# In Debian's repos, so this is a plain apt install -- the work here is the
# two things apt doesn't do for us:
#
#   1. The tray icon. `kdeconnect` ships an autostart entry for the daemon
#      (kdeconnectd) but not for the indicator, and the daemon alone gives
#      no visible tray presence. kdeconnect-indicator is SNI-native
#      (StatusNotifierItem), which is exactly what this machine's tray
#      stack wants -- same reason we run nm-tray over nm-applet (see
#      setup/87-i3.sh and dotfiles/autostart/nm-applet.desktop). We
#      autostart it via dotfiles/autostart/.config/autostart/
#      kdeconnect-indicator.desktop, which covers both the stock
#      "Xfce Session" and "Xfce with i3" (dex --autostart) profiles.
#
#   2. The firewall. KDE Connect's discovery + transport use TCP *and* UDP
#      1714-1764. This machine runs no firewall today (no ufw/firewalld),
#      so nothing needs opening. The guarded block below is a no-op now and
#      only does anything if a ufw firewall is ever added -- cheap insurance
#      so pairing doesn't silently fail the day that changes.

set -euo pipefail

log() { printf "  -> %s\n" "$*"; }

sudo apt-get install -y kdeconnect

# Open the KDE Connect port range only if ufw is actually present. `ufw
# allow` is idempotent (re-adding an existing rule is a no-op), and the
# command guard means this whole block evaporates on a machine with no ufw.
if command -v ufw >/dev/null 2>&1; then
    log "opening KDE Connect ports 1714:1764 (tcp+udp) in ufw"
    sudo ufw allow 1714:1764/tcp
    sudo ufw allow 1714:1764/udp
fi

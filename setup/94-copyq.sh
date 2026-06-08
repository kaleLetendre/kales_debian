#!/usr/bin/env bash
# 94-copyq.sh - CopyQ clipboard manager.
#
# Why: clipboard history (paste-from-anything-you-copied-recently).
# The Debian package ships no autostart of its own (dpkg -L copyq shows
# nothing under /etc/xdg/autostart or /usr/lib/systemd), so we provide
# one via dotfiles/autostart/.config/autostart/copyq.desktop. That covers
# both the regular Xfce Session and "Xfce with i3" (dex --autostart
# replays XDG autostart entries). The Super+P hotkey to open the window
# is wired separately:
#   - setup/76-app-hotkeys.sh         (XFCE / xfwm4 session)
#   - dotfiles/i3/.config/i3/config   (Xfce-with-i3 session)

set -euo pipefail

sudo apt-get install -y copyq

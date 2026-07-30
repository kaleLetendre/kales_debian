#!/usr/bin/env bash
# 61-x11vnc.sh - x11vnc, for viewing this machine's real :0 desktop from
# another Tailscale node. Idempotent.
#
# Pairs with dotfiles/bin/bin/remote-display, which starts x11vnc bound to
# localhost only (reached over an SSH tunnel, never exposed to the network)
# and is launched at login by
# dotfiles/autostart/.config/autostart/remote-display.desktop.
# Without this package those scripts fail with "command not found".
#
# Why x11vnc and not a standalone VNC server (tigervnc, x0vncserver):
# x11vnc attaches to the *existing* :0 session with both monitors, so you
# see the actual desktop you walked away from. A standalone server would
# spawn a second, separate desktop instead.
#
# On the number: the 90-99 block was already full when this was added, and
# a `100-` prefix would sort before `20-` in lex order. This module only
# installs a package, so its position carries no dependency meaning.

set -euo pipefail

sudo apt-get install -y x11vnc

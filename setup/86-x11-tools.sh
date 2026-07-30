#!/usr/bin/env bash
# 86-x11-tools.sh - X11 input + window scripting utilities. Not tied to
# any specific WM; these are general helpers for a keyboard-driven
# workflow.
#
#   xdotool       - simulate keys / mouse / window actions from a
#                   script. Useful when a keybinding needs to do
#                   something the WM has no built-in action for.
#   xinput        - list and configure X input devices (touchpad
#                   options, per-device repeat rate, etc).
#   x11-xkb-utils - ships `xev` (read what a key actually emits;
#                   essential when debugging i3 / xfwm4 bindings) and
#                   `setxkbmap` (set keyboard layout).
#   x11-xserver-utils - ships `xsetroot` (paint the X root window) and
#                   `xrandr`. The i3 config uses `xsetroot -solid` at
#                   login to blank the root so SDDM's greeter image
#                   doesn't linger on the desktop; see dotfiles/i3.
#
# apt-get install -y is idempotent on already-installed packages, so
# re-running this script is a no-op.

set -euo pipefail

sudo apt-get install -y xdotool xinput x11-xkb-utils x11-xserver-utils

#!/usr/bin/env bash
# 28-serial.sh - serial-console tooling for debugging embedded devices.
# Idempotent.
#
# The Linux answer to TeraTerm/PuTTY serial mode. `tio` is a modern, no-fuss
# serial terminal: `tio /dev/ttyUSB0` connects at sane defaults, auto-reconnects
# when a device re-enumerates (unplug/replug, board reset), and has clean
# logging -- much nicer for day-to-day poking than minicom's menus.
#
#   tio  - the serial terminal itself (Debian package `tio`).
#
# Access gotcha: USB/ACM serial adapters expose /dev/ttyUSB* and /dev/ttyACM*
# owned by group `dialout`. Without membership you'd need sudo on every
# connect, so add the invoking user to dialout. Group changes only take
# effect on the next login, so this is a one-time thing that survives reboots.
#
# Generic dev tooling (any machine debugging serial benefits), so setup/ rather
# than hardware/precision-3591.sh.

set -euo pipefail

sudo apt-get install -y tio

# Add the user to `dialout` for sudo-free access to serial devices.
# `id -nG` lists current groups; only usermod if we're not already in it.
if ! id -nG "$USER" | grep -qw dialout; then
    sudo usermod -aG dialout "$USER"
    echo "Added $USER to 'dialout'. Log out and back in for it to take effect."
fi

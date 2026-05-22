#!/usr/bin/env bash
# 88-keyboard.sh - F-row default for Apple-style keyboards.
#
# The RK987A (and other clones that report Apple's USB VID 05ac when
# they're in "Mac mode") are claimed by the kernel's hid_apple driver.
# Its `fnmode` parameter controls what the F-row sends by default:
#
#   1 = F-keys behave as media keys; Fn+F-key = real F-key
#       (Apple's hardware default)
#   2 = F-keys behave as F-keys; Fn+F-key = media key
#       (what we want -- Alt+F4, Alt+F7, F2-to-rename etc all work)
#   3 = kernel auto-pick
#       (Trixie's default; on the RK987A this lands on the wrong
#       behavior and makes Alt+F4 inert)
#
# We persist the choice in /etc/modprobe.d/ (read on the next module
# load) AND poke the live sysfs param so it takes effect immediately
# without a reboot.

set -euo pipefail

SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

CONF=/etc/modprobe.d/hid_apple.conf
BODY="options hid_apple fnmode=2"

if [[ ! -f "$CONF" ]] || ! diff -q <(printf '%s\n' "$BODY") "$CONF" >/dev/null 2>&1; then
    log "writing $CONF"
    printf '%s\n' "$BODY" | $SUDO tee "$CONF" >/dev/null
else
    log "$CONF already in place"
fi

# Live sysfs param exists only while hid_apple is loaded. If no Apple-
# style keyboard has been plugged in / connected yet on this boot, the
# module isn't loaded and the modprobe config takes care of the next
# load on its own.
LIVE=/sys/module/hid_apple/parameters/fnmode
if [[ -e "$LIVE" ]]; then
    current="$(cat "$LIVE")"
    if [[ "$current" != "2" ]]; then
        log "setting fnmode=2 at runtime (was $current)"
        echo 2 | $SUDO tee "$LIVE" >/dev/null
    else
        log "fnmode already 2 at runtime"
    fi
else
    log "hid_apple not loaded; modprobe config applies on next load"
fi

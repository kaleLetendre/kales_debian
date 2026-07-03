#!/usr/bin/env bash
# 97-webcam.sh - userspace tooling for the webcam. Idempotent.
#
# NOT a driver install. The built-in webcams on this hardware (a Realtek
# "Integrated_Webcam_FHD" plus an IR camera) are standard USB Video Class
# devices, so the kernel's in-tree uvcvideo driver claims them with no
# help -- /dev/video* nodes just appear, and logind hands the active user
# an ACL on them (we're also in the `video` group). Browsers, Signal, etc.
# already see /dev/video0 directly. What was actually missing was anything
# to *view and test* the camera locally, hence this module.
#
#   v4l-utils  - v4l2-ctl, for listing/inspecting the cameras. Handy because
#                the FHD and IR cameras expose several /dev/video nodes
#                (capture + metadata for each), so the real capture device
#                isn't always video0. `v4l2-ctl --list-devices` sorts that out.
#   guvcview   - lightweight GTK viewer with live UVC controls (exposure,
#                focus, resolution). Picked over cheese to keep GNOME deps off
#                this XFCE/i3 box.
#
# Generic (any machine with a camera benefits), so it lives in setup/ rather
# than hardware/precision-3591.sh.

set -euo pipefail

sudo apt-get install -y v4l-utils guvcview

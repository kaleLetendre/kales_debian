#!/usr/bin/env bash
# 91-autorandr.sh - hotplug-driven xrandr layouts via autorandr.
#
# Why this exists: XFCE's displays.xml ("Default" profile) is applied at
# session start, not when a monitor is hot-plugged. Re-plugging an external
# monitor reverts to its preferred mode (often 1080p on 4K-class panels),
# which on a high-DPI laptop pairing looks zoomed-in / oversized.
# autorandr fingerprints the connected EDID set, watches udev, and re-applies
# the saved xrandr layout that matches. Desktop-agnostic, simple, robust.
#
# Profiles themselves are user data: save them with `autorandr --save NAME`
# while the desired layout is active. They live under ~/.config/autorandr/.
# If you want a profile to ship with the repo, stow it via
# dotfiles/autorandr/.config/autorandr/<name>/{setup,config}.

set -euo pipefail

log() { printf "  -> %s\n" "$*"; }

sudo apt-get install -y autorandr

# The Debian package installs:
#   /usr/lib/udev/rules.d/40-monitor-hotplug.rules  (hotplug trigger)
#   /etc/xdg/autostart/autorandr.desktop            (session-start fallback)
#   /usr/lib/systemd/system/autorandr-lid-listener.service  (lid events)
#   /usr/lib/systemd/system/autorandr.service               (the worker)
# Nothing to enable manually; the udev rule fires autorandr.service on
# every DRM hotplug event, and the autostart entry covers cold boot when
# the monitor is already plugged in.

# Hotplug race fix: the udev rule fires on the first DRM "change" event,
# but at that instant a freshly plugged HDMI/DP monitor's EDID often
# isn't fully enumerated yet. autorandr then sees no matching profile,
# exits without switching, and the i3 postswitch hook never runs -- so
# workspaces stay on the wrong outputs even though the layout is "right".
# Sleep before inspecting so DRM has time to settle. 2s was not enough on
# the Precision 3591 + Dell S3225QS over HDMI -- every hotplug event lost
# the race and committed to the laptop-only profile, leaving the system
# with both panels lit but no primary set. 5s has held.
# Drop-in lives in /etc (not /usr/lib) so package upgrades don't clobber.
log "autorandr hotplug delay drop-in"
sudo install -d -m 755 /etc/systemd/system/autorandr.service.d
sudo tee /etc/systemd/system/autorandr.service.d/hotplug-delay.conf >/dev/null <<'EOF'
# Managed by kales_debian/setup/91-autorandr.sh
[Service]
ExecStartPre=/bin/sleep 5
EOF
sudo systemctl daemon-reload

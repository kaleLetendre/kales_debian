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

# Make autorandr the SOLE display authority -- stop xfsettingsd clobbering it.
#
# xfsettingsd (started by 87-i3.sh for themes/xsettings/hotkeys, so we can't
# just not run it) also carries a display helper. Its stored "Default" profile
# marks BOTH outputs Primary=false, and with /AutoEnableProfiles on it re-applies
# that profile on every RandR event (DPMS wake, hotplug, mode query). That wipes
# the `primary` flag autorandr's desk profile set at login. With no primary, i3
# can't resolve `nonprimary`, so the next workspace created strands on the laptop
# panel -- and autorandr's postswitch hook never runs, because *autorandr* didn't
# switch, xfsettingsd did, behind its back. Symptom: workspaces 6-9 drift off the
# external monitor hours after login for no visible reason.
#
# Two idempotent xfconf fixes (xfconf-query is the repo's settings pattern, cf.
# 87-i3.sh). Belt: stop the helper auto-applying displays at all, leaving
# autorandr (udev + the i3-start `autorandr --change --force`) as the only thing
# that touches geometry/primary. Suspenders: mark the laptop panel primary in
# XFCE's own profile too, so if the helper ever does apply, it sets the same
# primary autorandr wants instead of clearing it. eDP-1 is the internal panel on
# this laptop (and the `primary` output in autorandr/desk); only set it when that
# subtree already exists, so this no-ops on a machine XFCE hasn't profiled yet.
log "disabling xfsettingsd display auto-management (autorandr owns displays)"
xfconf-query -c displays -p /AutoEnableProfiles --create -t int -s 0
xfconf-query -c displays -p /Notify --create -t int -s 0
if xfconf-query -c displays -p /Default/eDP-1/Primary >/dev/null 2>&1; then
    log "marking eDP-1 primary in XFCE's displays profile"
    xfconf-query -c displays -p /Default/eDP-1/Primary --create -t bool -s true
fi

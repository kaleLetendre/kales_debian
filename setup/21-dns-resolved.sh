#!/usr/bin/env bash
# 21-dns-resolved.sh - make systemd-resolved the single DNS arbiter, so
# NetworkManager and Tailscale stop fighting over /etc/resolv.conf. Idempotent.
#
# The problem this fixes: with no resolver daemon, NetworkManager (default mode)
# writes /etc/resolv.conf from the connection's DHCP DNS, and Tailscale *also*
# writes it to install MagicDNS (100.100.100.100 + the *.ts.net search domain).
# They take turns clobbering the flat file, so MagicDNS drops out every time the
# network reconnects until Tailscale notices and rewrites it. `tailscale status`
# flags this as "System DNS config not ideal / resolv.conf overwritten".
#
# The fix: run systemd-resolved as the one thing that owns /etc/resolv.conf.
# NetworkManager then hands it the per-link DHCP servers, and Tailscale registers
# MagicDNS + split-DNS through resolved's D-Bus API instead of the flat file.
# No more fight, and -- unlike `NetworkManager dns=none` (let Tailscale solely
# own the file) -- normal DNS keeps working even when tailscaled is down.
#
# Generic to any Debian + NetworkManager + Tailscale box, so setup/ not hardware/.
# Ordering: runs early (before app modules) so system DNS is sane; the NM/
# tailscaled reconfig below is what makes the resolv.conf symlink actually stick,
# so those must happen before the symlink is (re)laid, not after.

set -euo pipefail

SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

# 1. The resolver daemon. On Debian 13 systemd-resolved is its own package
#    (split out of systemd), and not installed by default.
if ! dpkg -s systemd-resolved >/dev/null 2>&1; then
    log "installing systemd-resolved"
    $SUDO apt-get install -y systemd-resolved
else
    log "systemd-resolved already installed"
fi
$SUDO systemctl enable --now systemd-resolved

# 2. Point NetworkManager at resolved instead of letting it write resolv.conf.
#    conf.d drop-in so we don't edit the shipped NetworkManager.conf.
NM_CONF="/etc/NetworkManager/conf.d/dns-systemd-resolved.conf"
NM_BODY=$'[main]\ndns=systemd-resolved\n'
if [[ ! -f "$NM_CONF" ]] || ! diff -q <(printf '%s' "$NM_BODY") "$NM_CONF" >/dev/null 2>&1; then
    log "writing $NM_CONF (dns=systemd-resolved)"
    $SUDO install -d -m 0755 "$(dirname "$NM_CONF")"
    printf '%s' "$NM_BODY" | $SUDO tee "$NM_CONF" >/dev/null
    # reload (not restart) re-reads conf.d without dropping active connections.
    $SUDO systemctl reload NetworkManager
else
    log "$NM_CONF already current"
fi

# 3. Nudge Tailscale to re-detect resolved and register MagicDNS via D-Bus
#    rather than rewriting the flat file. Only if tailscaled is actually here.
if systemctl list-unit-files tailscaled.service >/dev/null 2>&1 \
   && systemctl is-active --quiet tailscaled; then
    log "restarting tailscaled so it picks up the resolved DNS path"
    $SUDO systemctl restart tailscaled
fi

# 4. Finally, hand /etc/resolv.conf to resolved's stub. Done LAST: now that
#    NM and Tailscale both feed resolved, nothing will overwrite this symlink.
#    ln -sf is idempotent (replaces a stale file or wrong-target link).
STUB="/run/systemd/resolve/stub-resolv.conf"
if [[ "$(readlink -f /etc/resolv.conf)" != "$STUB" ]]; then
    log "linking /etc/resolv.conf -> $STUB"
    $SUDO ln -sf "$STUB" /etc/resolv.conf
else
    log "/etc/resolv.conf already points at the resolved stub"
fi

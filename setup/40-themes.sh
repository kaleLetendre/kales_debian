#!/usr/bin/env bash
# 40-themes.sh - install Sweet-Dark GTK/xfwm4 theme + candy-icons and apply
# via xfconf-query. Idempotent.
#
# Both themes are by EliverLara and are designed to pair. See THEMES.md for
# the design notes; this file owns the actual install + apply.
#
# Sweet: the upstream master is unbuilt source (Sass + gulp). The release
# tarballs ship the compiled theme directly, so we fetch a pinned release
# rather than cloning + building. Bump SWEET_VERSION to update.

set -euo pipefail

log() { printf "  -> %s\n" "$*"; }

THEMES_DIR="$HOME/.themes"
ICONS_DIR="$HOME/.icons"

SWEET_VERSION="v6.0"
SWEET_ASSET="Sweet-Dark.tar.xz"
SWEET_URL="https://github.com/EliverLara/Sweet/releases/download/${SWEET_VERSION}/${SWEET_ASSET}"

mkdir -p "$THEMES_DIR" "$ICONS_DIR"

# 1. Sweet-Dark GTK + xfwm4 theme from the pinned release tarball.
if [[ ! -d "$THEMES_DIR/Sweet-Dark" ]]; then
    log "downloading Sweet-Dark ${SWEET_VERSION}"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL "$SWEET_URL" -o "$tmp/${SWEET_ASSET}"
    log "extracting to $THEMES_DIR/Sweet-Dark"
    tar -xJf "$tmp/${SWEET_ASSET}" -C "$THEMES_DIR/"
    rm -rf "$tmp"
    trap - EXIT
fi

# 2. candy-icons. The repo IS the icon theme, so clone straight into the
#    icons dir and drop the git metadata to keep ~/.icons tidy.
if [[ ! -d "$ICONS_DIR/candy-icons" ]]; then
    log "fetching candy-icons"
    git clone --depth 1 https://github.com/EliverLara/candy-icons.git \
        "$ICONS_DIR/candy-icons"
    rm -rf "$ICONS_DIR/candy-icons/.git" "$ICONS_DIR/candy-icons/.github"
fi

# 3. Apply. xfconf-query setting a property to its current value is a no-op,
#    so this is idempotent. Guarded on xfconf-query presence + a reachable
#    DBus session so this module still works (install-only) when invoked
#    from a non-XFCE shell (SSH, tty, first-boot without login).
if command -v xfconf-query >/dev/null 2>&1 && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    log "applying themes via xfconf-query"
    xfconf-query -c xsettings -p /Net/ThemeName     -s "Sweet-Dark"  || true
    xfconf-query -c xsettings -p /Net/IconThemeName -s "candy-icons" || true
    xfconf-query -c xfwm4     -p /general/theme     -s "Sweet-Dark"  || true
else
    log "xfconf-query unavailable or no DBus session; skipping apply"
    log "    (re-run from an XFCE terminal to apply, or apply manually)"
fi

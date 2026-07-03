#!/usr/bin/env bash
# 99-i3lock-color.sh - build i3lock-color from source (it is NOT packaged in
# Debian) and install it as /usr/local/bin/i3lock-color, leaving Debian's
# /usr/bin/i3lock untouched. Gives the blur + clock + state-colored-ring lock
# screen vanilla i3lock can't. The actual flags live in
# dotfiles/i3/.config/i3/lock.sh, which prefers this binary and falls back to
# vanilla i3lock when it is absent, so the lock keybind always works.
# Idempotent: exits early when the pinned version is already installed.
#
# Source: github.com/Raymo111/i3lock-color (Cassandra Fox / Raymond Li fork).
#
# Install name: upstream `make install` lands as /usr/bin/i3lock and would
# clobber Debian's i3lock package (and its /etc/pam.d/i3lock). We build, then
# copy the binary to a DISTINCT name, so both coexist and dpkg stays happy.
#
# PAM / lockout safety: the binary calls pam_start("i3lock", ...) -- the same
# service name as upstream -- so it authenticates via /etc/pam.d/i3lock, which
# Debian's i3lock package ships (installed by 87-i3.sh). We assert that file
# exists; without it the lock screen could never accept a password.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

BIN=/usr/local/bin/i3lock-color
SRC="$HOME/.local/src/i3lock-color"
REPO="https://github.com/Raymo111/i3lock-color.git"
# Pinned release tag: a build is reproducible (not "whatever HEAD is today"),
# and its option set matches the flags in lock.sh. Bump deliberately, and
# re-check lock.sh's flags against the new version when you do.
PIN="2.13.c.5"

# 0. PAM service file. Debian's i3lock package provides /etc/pam.d/i3lock, the
#    service i3lock-color authenticates against. 87-i3.sh installs i3lock, but
#    be defensive here -- a missing PAM file means an unlockable screen.
if [[ ! -f /etc/pam.d/i3lock ]]; then
    log "installing i3lock (provides /etc/pam.d/i3lock, the PAM service)"
    $SUDO apt-get install -y i3lock
fi

# 1. Skip everything if the pinned version is already installed.
if [[ -x "$BIN" ]] && "$BIN" --version 2>&1 | grep -q "$PIN"; then
    log "i3lock-color $PIN already installed at $BIN"
    exit 0
fi

# 2. Build deps (all confirmed present in Debian 13 repos). automake is needed
#    for AM_INIT_AUTOMAKE in configure.ac; autoreconf pulls in the rest.
log "installing build deps"
$SUDO apt-get install -y \
    autoconf automake gcc make pkg-config \
    libpam0g-dev libcairo2-dev libfontconfig1-dev libxcb-composite0-dev \
    libev-dev libx11-xcb-dev libxcb-xkb-dev libxcb-xinerama0-dev \
    libxcb-randr0-dev libxcb-image0-dev libxcb-util0-dev libxcb-xrm-dev \
    libxkbcommon-dev libxkbcommon-x11-dev libjpeg-dev

# 3. Clone (FULL, with tags -- configure derives the version via `git
#    describe`, so a shallow clone or tarball would break the build) and pin.
if [[ ! -d "$SRC/.git" ]]; then
    log "cloning i3lock-color -> $SRC"
    mkdir -p "$(dirname "$SRC")"
    git clone "$REPO" "$SRC"
fi
git -C "$SRC" fetch --tags --force
git -C "$SRC" checkout "$PIN"

# 4. Build. build.sh runs autoreconf + configure + make into ./build/, leaving
#    the binary at build/i3lock. We deliberately do NOT run `make install` (it
#    targets --prefix=/usr and would overwrite Debian's i3lock); copy by hand.
log "building i3lock-color $PIN (compiles; ~1 min)"
( cd "$SRC" && bash ./build.sh )
$SUDO install -m 0755 "$SRC/build/i3lock" "$BIN"

# 5. Lockout guard: reassert the PAM service file is present after the build.
if [[ ! -f /etc/pam.d/i3lock ]]; then
    echo "ERROR: /etc/pam.d/i3lock missing -- i3lock-color cannot authenticate." >&2
    exit 1
fi

log "installed: $("$BIN" --version 2>&1 | head -1)"
log "lock command lives in dotfiles/i3/.config/i3/lock.sh (auto-uses this binary)"

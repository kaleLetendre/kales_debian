#!/usr/bin/env bash
# 27-android-studio.sh - install Android Studio from the official Google
# Linux tarball. Idempotent.
#
# Android Studio isn't in Debian's repos and has no apt repo, so -- same
# pattern as 72-postman.sh -- we extract to /opt/android-studio, symlink
# the launcher, and drop a .desktop file. Idempotent: skips work if
# /opt/android-studio/bin/studio is already present.
#
# We launch via the native bin/studio binary rather than the legacy
# bin/studio.sh shell wrapper -- the IDE itself nags to switch, and the
# native launcher starts faster and integrates better.
#
# Google has no stable "latest" URL: the download path carries an exact
# build number and a release code name. So we pin the full URL below.
# To bump: grab the current Linux .tar.gz link from
#   https://developer.android.com/studio#downloads
# and replace TARBALL_URL (the tarball always unpacks to android-studio/).
# Then `sudo rm -rf /opt/android-studio` and re-run to force the upgrade.
#
# The emulator additionally needs KVM (hardware virtualization + your user
# in the `kvm` group). That is handled by the IDE's own setup prompts and
# is machine/BIOS dependent, so it is intentionally left out of here.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

INSTALL_DIR="/opt/android-studio"
BIN_LINK="/usr/local/bin/android-studio"
DESKTOP_PATH="/usr/share/applications/android-studio.desktop"
# Pinned build: Android Studio Quail 1 | 2026.1.1 Patch 2 (see header to bump).
TARBALL_URL="https://edgedl.me.gvt1.com/android/studio/ide-zips/2026.1.1.10/android-studio-quail1-patch2-linux.tar.gz"

need_pkgs=()
command -v curl >/dev/null 2>&1 || need_pkgs+=(curl)
command -v tar  >/dev/null 2>&1 || need_pkgs+=(tar)
dpkg -s ca-certificates >/dev/null 2>&1 || need_pkgs+=(ca-certificates)
if (( ${#need_pkgs[@]} > 0 )); then
    log "installing prereqs: ${need_pkgs[*]}"
    $SUDO apt-get update
    $SUDO apt-get install -y "${need_pkgs[@]}"
fi

if [[ ! -x "$INSTALL_DIR/bin/studio" ]]; then
    log "downloading Android Studio tarball (~1.5 GB)"
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    curl -fSL "$TARBALL_URL" -o "$tmpdir/android-studio.tar.gz"

    log "extracting to $INSTALL_DIR"
    $SUDO rm -rf "$INSTALL_DIR"
    $SUDO install -d -m 0755 "$(dirname "$INSTALL_DIR")"
    # Tarball top-level dir is "android-studio/".
    $SUDO tar -xzf "$tmpdir/android-studio.tar.gz" -C "$(dirname "$INSTALL_DIR")"
else
    log "$INSTALL_DIR already present (rm -rf $INSTALL_DIR to reinstall)"
fi

if [[ "$(readlink -f "$BIN_LINK" 2>/dev/null || true)" != "$INSTALL_DIR/bin/studio" ]]; then
    log "linking $BIN_LINK -> $INSTALL_DIR/bin/studio"
    $SUDO ln -sfn "$INSTALL_DIR/bin/studio" "$BIN_LINK"
fi

read -r -d '' DESKTOP_BODY <<EOF || true
[Desktop Entry]
Name=Android Studio
GenericName=Android IDE
Comment=The official Android IDE
Exec=$INSTALL_DIR/bin/studio %f
Icon=$INSTALL_DIR/bin/studio.png
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=jetbrains-studio
StartupNotify=true
EOF

if [[ ! -f "$DESKTOP_PATH" ]] || ! diff -q <(printf '%s\n' "$DESKTOP_BODY") "$DESKTOP_PATH" >/dev/null 2>&1; then
    log "writing $DESKTOP_PATH"
    printf '%s\n' "$DESKTOP_BODY" | $SUDO tee "$DESKTOP_PATH" >/dev/null
fi

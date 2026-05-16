#!/usr/bin/env bash
# 72-postman.sh - install Postman from the official Linux tarball.
# No upstream apt repo exists for Postman, so we extract to /opt/Postman,
# symlink the launcher, and drop a .desktop file. Idempotent: skips work
# if /opt/Postman/Postman is already present.
#
# Re-run after `sudo rm -rf /opt/Postman` to force a reinstall to the
# current latest build.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

INSTALL_DIR="/opt/Postman"
BIN_LINK="/usr/local/bin/postman"
DESKTOP_PATH="/usr/share/applications/postman.desktop"
TARBALL_URL="https://dl.pstmn.io/download/latest/linux_64"

need_pkgs=()
command -v curl >/dev/null 2>&1 || need_pkgs+=(curl)
command -v tar  >/dev/null 2>&1 || need_pkgs+=(tar)
dpkg -s ca-certificates >/dev/null 2>&1 || need_pkgs+=(ca-certificates)
if (( ${#need_pkgs[@]} > 0 )); then
    log "installing prereqs: ${need_pkgs[*]}"
    $SUDO apt-get update
    $SUDO apt-get install -y "${need_pkgs[@]}"
fi

if [[ ! -x "$INSTALL_DIR/Postman" ]]; then
    log "downloading Postman tarball"
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    curl -fsSL "$TARBALL_URL" -o "$tmpdir/postman.tar.gz"

    log "extracting to $INSTALL_DIR"
    $SUDO rm -rf "$INSTALL_DIR"
    $SUDO install -d -m 0755 "$(dirname "$INSTALL_DIR")"
    # Tarball top-level dir is "Postman/".
    $SUDO tar -xzf "$tmpdir/postman.tar.gz" -C "$(dirname "$INSTALL_DIR")"
else
    log "$INSTALL_DIR/Postman already present (rm -rf $INSTALL_DIR to reinstall)"
fi

if [[ "$(readlink -f "$BIN_LINK" 2>/dev/null || true)" != "$INSTALL_DIR/Postman" ]]; then
    log "linking $BIN_LINK -> $INSTALL_DIR/Postman"
    $SUDO ln -sfn "$INSTALL_DIR/Postman" "$BIN_LINK"
fi

read -r -d '' DESKTOP_BODY <<EOF || true
[Desktop Entry]
Name=Postman
GenericName=API Client
Comment=API development environment
Exec=$INSTALL_DIR/Postman %U
Icon=$INSTALL_DIR/app/resources/app/assets/icon.png
Terminal=false
Type=Application
Categories=Development;
StartupWMClass=Postman
MimeType=x-scheme-handler/postman;
EOF

if [[ ! -f "$DESKTOP_PATH" ]] || ! diff -q <(printf '%s\n' "$DESKTOP_BODY") "$DESKTOP_PATH" >/dev/null 2>&1; then
    log "writing $DESKTOP_PATH"
    printf '%s\n' "$DESKTOP_BODY" | $SUDO tee "$DESKTOP_PATH" >/dev/null
fi

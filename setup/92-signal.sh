#!/usr/bin/env bash
# 92-signal.sh - Signal Desktop from the official Signal apt repo. Idempotent.
#
# Matches the third-party-apt-repo pattern of 73-vivaldi.sh:
# install prereqs, install signing key once, write the source list, then
# apt install. apt update only runs when sources actually changed or the
# target package isn't installed yet -- keeps re-runs cheap.
#
# The "xenial" in the deb URI is a fixed identifier upstream uses for the
# only suite they publish; it isn't a Debian/Ubuntu codename match. Has
# not changed in years and works fine on Debian Trixie.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

need_pkgs=()
command -v curl >/dev/null 2>&1 || need_pkgs+=(curl)
command -v gpg  >/dev/null 2>&1 || need_pkgs+=(gnupg)
dpkg -s ca-certificates >/dev/null 2>&1 || need_pkgs+=(ca-certificates)
if (( ${#need_pkgs[@]} > 0 )); then
    log "installing prereqs: ${need_pkgs[*]}"
    $SUDO apt-get update
    $SUDO apt-get install -y "${need_pkgs[@]}"
fi

KEY_PATH="/etc/apt/keyrings/signal-desktop.gpg"
LIST_PATH="/etc/apt/sources.list.d/signal-xenial.list"
LIST_BODY="deb [arch=amd64 signed-by=$KEY_PATH] https://updates.signal.org/desktop/apt xenial main"

sources_changed=0

if [[ ! -s "$KEY_PATH" ]]; then
    log "installing Signal signing key -> $KEY_PATH"
    $SUDO install -d -m 0755 "$(dirname "$KEY_PATH")"
    curl -fsSL https://updates.signal.org/desktop/apt/keys.asc \
        | gpg --dearmor \
        | $SUDO tee "$KEY_PATH" >/dev/null
    $SUDO chmod 0644 "$KEY_PATH"
    sources_changed=1
fi

if [[ ! -f "$LIST_PATH" ]] || ! diff -q <(printf '%s\n' "$LIST_BODY") "$LIST_PATH" >/dev/null 2>&1; then
    log "writing $LIST_PATH"
    printf '%s\n' "$LIST_BODY" | $SUDO tee "$LIST_PATH" >/dev/null
    sources_changed=1
fi

if (( sources_changed )) || ! dpkg -s signal-desktop >/dev/null 2>&1; then
    $SUDO apt-get update
fi

if ! dpkg -s signal-desktop >/dev/null 2>&1; then
    log "installing signal-desktop"
    $SUDO apt-get install -y signal-desktop
else
    log "signal-desktop already installed"
fi

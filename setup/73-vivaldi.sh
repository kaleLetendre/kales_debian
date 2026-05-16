#!/usr/bin/env bash
# 73-vivaldi.sh - install Vivaldi browser from the official Vivaldi apt
# repo. Idempotent.

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

KEY_PATH="/etc/apt/keyrings/vivaldi.gpg"
LIST_PATH="/etc/apt/sources.list.d/vivaldi.list"
LIST_BODY="deb [signed-by=$KEY_PATH] https://repo.vivaldi.com/archive/deb/ stable main"

sources_changed=0

if [[ ! -s "$KEY_PATH" ]]; then
    log "installing Vivaldi signing key -> $KEY_PATH"
    $SUDO install -d -m 0755 "$(dirname "$KEY_PATH")"
    curl -fsSL https://repo.vivaldi.com/archive/linux_signing_key.pub \
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

if (( sources_changed )) || ! dpkg -s vivaldi-stable >/dev/null 2>&1; then
    $SUDO apt-get update
fi

if ! dpkg -s vivaldi-stable >/dev/null 2>&1; then
    log "installing vivaldi-stable"
    $SUDO apt-get install -y vivaldi-stable
else
    log "vivaldi-stable already installed"
fi

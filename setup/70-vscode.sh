#!/usr/bin/env bash
# 70-vscode.sh - install Microsoft Visual Studio Code from the official
# Microsoft apt repo. Idempotent.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

# Tools needed to fetch + dearmor the signing key.
need_pkgs=()
command -v curl >/dev/null 2>&1 || need_pkgs+=(curl)
command -v gpg  >/dev/null 2>&1 || need_pkgs+=(gnupg)
dpkg -s ca-certificates >/dev/null 2>&1 || need_pkgs+=(ca-certificates)
if (( ${#need_pkgs[@]} > 0 )); then
    log "installing prereqs: ${need_pkgs[*]}"
    $SUDO apt-get update
    $SUDO apt-get install -y "${need_pkgs[@]}"
fi

KEY_PATH="/etc/apt/keyrings/microsoft.gpg"
LIST_PATH="/etc/apt/sources.list.d/vscode.list"
LIST_BODY="deb [arch=amd64,arm64,armhf signed-by=$KEY_PATH] https://packages.microsoft.com/repos/code stable main"

sources_changed=0

if [[ ! -s "$KEY_PATH" ]]; then
    log "installing Microsoft signing key -> $KEY_PATH"
    $SUDO install -d -m 0755 "$(dirname "$KEY_PATH")"
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
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

if (( sources_changed )) || ! dpkg -s code >/dev/null 2>&1; then
    $SUDO apt-get update
fi

if ! dpkg -s code >/dev/null 2>&1; then
    log "installing code"
    $SUDO apt-get install -y code
else
    log "code already installed"
fi

#!/usr/bin/env bash
# 39-discord.sh - install Discord (voice/text chat). Idempotent.
#
# Discord isn't in Debian's repos and has no apt repo; upstream serves the
# current .deb from a stable redirect URL, so fetch that -- same pattern as
# 95-obsidian.sh.
#
# Trade-off: no apt auto-updates. Discord nags "update available" and
# refuses to start when the .deb is too old; to upgrade, `apt remove
# discord` and re-run this module.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

DEB_URL="https://discord.com/api/download?platform=linux&format=deb"

need_pkgs=()
command -v curl >/dev/null 2>&1 || need_pkgs+=(curl)
dpkg -s ca-certificates >/dev/null 2>&1 || need_pkgs+=(ca-certificates)
if (( ${#need_pkgs[@]} > 0 )); then
    log "installing prereqs: ${need_pkgs[*]}"
    $SUDO apt-get update
    $SUDO apt-get install -y "${need_pkgs[@]}"
fi

if ! dpkg -s discord >/dev/null 2>&1; then
    log "downloading discord .deb"
    tmpdeb="$(mktemp --suffix=.deb)"
    trap 'rm -f "$tmpdeb"' EXIT
    curl -fsSL "$DEB_URL" -o "$tmpdeb"
    # mktemp makes it 0600; apt's sandbox user _apt must be able to read it,
    # else apt warns and falls back to reading it unsandboxed as root.
    chmod 644 "$tmpdeb"
    log "installing discord"
    # apt resolves the .deb's deps directly (modern apt).
    $SUDO apt-get install -y "$tmpdeb"
else
    log "discord already installed"
fi

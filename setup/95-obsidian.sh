#!/usr/bin/env bash
# 95-obsidian.sh - install Obsidian (Markdown notes / knowledge base).
# Idempotent.
#
# Obsidian isn't in Debian's repos and has no apt repo, so we fetch the
# latest .deb from the upstream GitHub release -- same pattern as
# 75-ulauncher.sh. Upstream ships obsidian_<ver>_amd64.deb on each
# release in obsidianmd/obsidian-releases.
#
# Trade-off: no apt auto-updates. Re-running this module will NOT upgrade
# an already-installed Obsidian (the dpkg guard short-circuits); to bump
# the version, `apt remove obsidian` first, then re-run.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

need_pkgs=()
command -v curl >/dev/null 2>&1 || need_pkgs+=(curl)
dpkg -s ca-certificates >/dev/null 2>&1 || need_pkgs+=(ca-certificates)
if (( ${#need_pkgs[@]} > 0 )); then
    log "installing prereqs: ${need_pkgs[*]}"
    $SUDO apt-get update
    $SUDO apt-get install -y "${need_pkgs[@]}"
fi

if ! dpkg -s obsidian >/dev/null 2>&1; then
    log "fetching latest obsidian .deb url from GitHub"
    deb_url="$(curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest \
        | grep -oE 'https://[^"]*obsidian_[0-9.]+_amd64\.deb' | head -1)"
    if [[ -z "$deb_url" ]]; then
        echo "could not find obsidian .deb in latest release" >&2
        exit 1
    fi
    log "downloading $deb_url"
    tmpdeb="$(mktemp --suffix=.deb)"
    trap 'rm -f "$tmpdeb"' EXIT
    curl -fsSL "$deb_url" -o "$tmpdeb"
    log "installing obsidian"
    # apt resolves the .deb's deps directly (modern apt).
    $SUDO apt-get install -y "$tmpdeb"
else
    log "obsidian already installed"
fi

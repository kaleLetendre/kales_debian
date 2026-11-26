#!/usr/bin/env bash
# server/31-steam.sh - Steam (Debian's steam-installer wrapper). Idempotent.
#
# Steam is a 32-bit client, so it needs the i386 architecture and the 32-bit
# GL userspace matching the 64-bit NVIDIA driver from server/30 -- without
# nvidia-driver-libs:i386 Steam falls back to software rendering or refuses
# to start games. Only pulled in when an NVIDIA GPU is present.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

if ! dpkg --print-foreign-architectures | grep -qx i386; then
    log "enabling i386 architecture"
    $SUDO dpkg --add-architecture i386
fi
$SUDO apt-get update

pkgs=(steam-installer)
if lspci -nd 10de: | grep -q ' 03'; then
    pkgs+=(nvidia-driver-libs:i386)
fi
log "installing ${pkgs[*]}"
$SUDO apt-get install -y "${pkgs[@]}"

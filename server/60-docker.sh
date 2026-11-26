#!/usr/bin/env bash
# server/60-docker.sh - Docker engine + compose from Debian's own packages.
# Idempotent.
#
# Debian's docker.io rather than Docker Inc's repo: it is what the server
# already runs, and it tracks security fixes through normal apt upgrades.
# docker-compose is the Debian-packaged v2 compose.
#
# Adding the user to `docker` lets them run docker without sudo. That is
# root-equivalent access, acceptable on a single-user box. Takes effect at
# next login.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

log "docker.io + docker-compose"
$SUDO apt-get install -y docker.io docker-compose

if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    log "adding $USER to docker group (re-login to apply)"
    $SUDO usermod -aG docker "$USER"
fi

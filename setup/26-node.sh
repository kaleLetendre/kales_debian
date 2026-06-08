#!/usr/bin/env bash
# 26-node.sh - Node.js runtime from Debian's apt repo. Idempotent.
#
# Debian 13 ships node 20.x LTS (current at time of writing). Installs the
# `nodejs` package only: just the JS runtime, no npm. Nothing on this
# machine has needed npm yet, and the `nodejs` package doesn't pull it in.
# If a project ever does need it: `sudo apt install npm` (Debian ships
# npm 9.x as a separate package).
#
# Why apt over NodeSource / fnm / nvm: simplest signed install, no extra
# repo to babysit, no shell-init complexity. If a project ever needs a
# newer node than Debian ships, revisit by adding a NodeSource module
# (same pattern as 30-claude-code.sh) -- don't paper over it with a
# per-user version manager.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

log "installing nodejs"
$SUDO apt-get install -y nodejs

node --version

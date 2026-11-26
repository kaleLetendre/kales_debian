#!/usr/bin/env bash
# server/52-uv-aider.sh - uv (Python package/tool manager) and aider (AI pair
# programming CLI) installed as a uv tool. Idempotent. Per-user, no sudo.
#
# uv's standalone installer drops uv/uvx into ~/.local/bin. UV_NO_MODIFY_PATH
# keeps it from editing shell rc files (those are stowed from the repo).
# `uv tool install` gives aider its own isolated venv, so its large pinned
# dependency set never collides with system or project Python packages.

set -euo pipefail

log() { printf "  -> %s\n" "$*"; }

export PATH="$HOME/.local/bin:$PATH"

if ! command -v uv >/dev/null 2>&1; then
    log "installing uv"
    curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
else
    log "uv already installed"
fi

if ! uv tool list | grep -q '^aider-chat '; then
    log "uv tool install aider-chat"
    uv tool install aider-chat
else
    log "aider already installed"
fi

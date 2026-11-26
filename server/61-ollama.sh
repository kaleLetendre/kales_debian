#!/usr/bin/env bash
# server/61-ollama.sh - Ollama (local LLM runtime) + the model the Discord
# bot uses. Idempotent.
#
# Ollama isn't packaged in Debian. Its official install.sh puts the binary in
# /usr/local/bin, creates an `ollama` system user/group, adds the current user
# to that group, and installs + enables ollama.service. On an NVIDIA box it
# uses the already-installed driver (server/30) and does not install its own.
#
# The model pull is a no-op when the model is already present.

set -euo pipefail

log() { printf "  -> %s\n" "$*"; }

# Model ~/personal/discord-ollama-bot talks to.
MODELS=(huihui_ai/qwen2.5-abliterate:7b)

if ! command -v ollama >/dev/null 2>&1; then
    log "installing ollama"
    curl -fsSL https://ollama.com/install.sh | sh
else
    log "ollama already installed"
fi

for m in "${MODELS[@]}"; do
    if ! ollama list | awk 'NR>1 {print $1}' | grep -qx "$m"; then
        log "pulling $m"
        ollama pull "$m"
    fi
done

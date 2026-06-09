#!/usr/bin/env bash
# 30-claude-code.sh - install Claude Code via Anthropic's native installer.
#
# Why native, not apt: the apt package lagged badly - we were stuck ~two model
# releases behind because the signed apt repo updates far slower than the
# release channel. The native install drops a self-updating binary in
# ~/.local/bin/claude that auto-updates in the background on the `latest`
# channel, so it picks up new versions as soon as they ship. Docs:
# https://code.claude.com/docs/en/setup
#
# This module also MIGRATES an existing apt install: if the claude-code
# package or its repo/key is present it removes them, so /usr/bin/claude
# doesn't linger and fight ~/.local/bin/claude on PATH. Idempotent.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

# ~/.local/bin is prepended to PATH by dotfiles/zsh/.zshrc.d/05-path.zsh,
# so the native binary takes precedence over anything in /usr/bin.
BIN="$HOME/.local/bin/claude"
LIST_PATH="/etc/apt/sources.list.d/claude-code.list"
KEY_PATH="/etc/apt/keyrings/claude-code.asc"

# 1. Tear down the old apt install if it's here. The apt binary lands in
#    /usr/bin/claude; we want the self-updating ~/.local/bin/claude to own
#    the name. Each check is guarded so re-runs are no-ops once it's gone.
if dpkg -s claude-code >/dev/null 2>&1; then
    log "removing old apt claude-code package"
    $SUDO apt-get remove -y claude-code
fi
if [[ -f "$LIST_PATH" ]]; then
    log "removing old apt repo $LIST_PATH"
    $SUDO rm -f "$LIST_PATH"
fi
if [[ -f "$KEY_PATH" ]]; then
    log "removing old apt signing key $KEY_PATH"
    $SUDO rm -f "$KEY_PATH"
fi

# 2. Native install. The installer itself is idempotent (re-running just
#    pulls the latest build), but once the binary exists we skip the network
#    fetch - background auto-update keeps it current from then on.
if [[ -x "$BIN" ]]; then
    log "native claude already installed at $BIN (auto-updates in background)"
else
    log "installing Claude Code via native installer"
    curl -fsSL https://claude.ai/install.sh | bash
fi

# 3. Ensure ~/.claude exists as a real directory before dotfiles stow runs.
#    Without this, `stow` would tree-fold the entire dotfiles/claude/.claude
#    package into a single symlink at ~/.claude, and claude-code's runtime
#    state (history.jsonl, sessions/, .credentials.json) would start landing
#    inside the repo. Creating the dir up front forces stow to fold at file
#    level, so only the tracked files (CLAUDE.md, settings.json) get symlinked.
mkdir -p "$HOME/.claude"

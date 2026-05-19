#!/usr/bin/env bash
# 31-claude-account.sh - confirm Claude Code is logged in and the
# Atlassian Rovo MCP (Jira/Confluence) is authenticated. Idempotent.
#
# Both steps are interactive OAuth flows that can't be automated from a
# script. This module's job is detection + clear next steps. It never
# blocks the bootstrap: if something is unfinished it prints what to do
# and exits 0 so the rest of bootstrap.sh still runs.
#
# The "claude.ai Atlassian Rovo" MCP is account-tied, not local config:
# it appears in `claude mcp list` only after `claude /login` succeeds
# with an account that has the Atlassian integration enabled on
# claude.ai. `claude mcp get` does NOT see it, only `claude mcp list`.

set -euo pipefail

CREDS="$HOME/.claude/.credentials.json"

log() { printf "  -> %s\n" "$*"; }

# 1. Is claude on PATH? 30-claude-code.sh should have installed it, but
#    don't assume - the apt install can be shadowed by ~/.local/bin/claude
#    or skipped entirely on re-runs.
if ! command -v claude >/dev/null 2>&1; then
    log "claude not on PATH - skipping (see 30-claude-code.sh)"
    exit 0
fi

# 2. Login state. .credentials.json is written by `claude /login`. If
#    missing or empty the user hasn't completed the OAuth handshake.
if [[ ! -s "$CREDS" ]]; then
    echo
    echo "Claude Code is not logged in to claude.ai."
    echo "Run:    claude"
    echo "then:   /login"
    echo "and complete the browser flow with the claude.ai account that"
    echo "owns the Atlassian (Jira/Confluence) integration. Then re-run"
    echo "this script to verify the MCP."
    exit 0
fi
log "claude code is logged in"

# 3. MCP state. `claude mcp list` queries each configured server and
#    appends "✓ Connected" or "! Needs authentication" per line. The
#    Atlassian Rovo entry is account-attached, so it shows up
#    automatically once login succeeds.
mcp_list="$(claude mcp list 2>&1 || true)"
atlassian_line="$(grep -i "Atlassian Rovo" <<<"$mcp_list" || true)"

if [[ -z "$atlassian_line" ]]; then
    echo
    echo "The Atlassian Rovo MCP is not listed by 'claude mcp list'."
    echo "Likely cause: the logged-in claude.ai account does not have the"
    echo "Atlassian integration enabled. Enable it at:"
    echo "  https://claude.ai/settings/connectors"
    echo "then re-run this script."
    exit 0
fi

if grep -q "Connected" <<<"$atlassian_line"; then
    log "atlassian rovo mcp: ✓ Connected"
    exit 0
fi

if grep -q "Needs authentication" <<<"$atlassian_line"; then
    echo
    echo "Atlassian Rovo MCP needs authentication."
    echo "Inside Claude Code:"
    echo "  1. run:  claude"
    echo "  2. run:  /mcp"
    echo "  3. select 'claude.ai Atlassian Rovo' and complete the OAuth flow"
    echo "Then re-run this script to verify."
    exit 0
fi

# Unknown state - print the line for debugging but don't fail.
log "atlassian rovo mcp: unrecognized state"
log "      $atlassian_line"

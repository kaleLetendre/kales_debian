#!/usr/bin/env bash
# 31-claude-account.sh - register Atlassian's Remote MCP (Jira/Confluence)
# at user scope and verify it is authenticated. Idempotent.
#
# Uses Atlassian's official Remote MCP Server, NOT the "claude.ai
# Atlassian Rovo" connector that claude.ai pre-wires into your account.
# Both endpoints share the URL https://mcp.atlassian.com/v1/mcp but the
# OAuth flows request different scopes: the Rovo connector asks for
# broad Rovo-agent permissions, while a manual `claude mcp add`
# registration goes through its own OAuth with just the core
# Jira/Confluence scopes (search/create/update/comment/transition/fetch).
# That is the lighter-permission setup we want.
#
# Endpoint per Atlassian's GA announcement (Feb 2026). The legacy SSE
# transport at /v1/sse is deprecated and will be removed 2026-06-30.
#
# This module never blocks the bootstrap: it registers what it can and
# prints clear next steps for the interactive OAuth handshake.

set -euo pipefail

MCP_NAME="atlassian"
MCP_URL="https://mcp.atlassian.com/v1/mcp"
CREDS="$HOME/.claude/.credentials.json"

log() { printf "  -> %s\n" "$*"; }

# 1. claude on PATH? 30-claude-code.sh should have installed it.
if ! command -v claude >/dev/null 2>&1; then
    log "claude not on PATH - skipping (see 30-claude-code.sh)"
    exit 0
fi

# 2. Logged in to claude.ai? .credentials.json is written by /login.
#    Without it, `claude mcp add` and `claude mcp list` may still work
#    but the MCP can't be used until login completes anyway, so bail
#    early with a clear next step.
if [[ ! -s "$CREDS" ]]; then
    echo
    echo "Claude Code is not logged in to claude.ai."
    echo "Run:    claude"
    echo "then:   /login"
    echo "then re-run this script."
    exit 0
fi
log "claude code is logged in"

# 3. Register the MCP at user scope so it's available from any working
#    directory. `claude mcp get` exits non-zero when the server isn't
#    registered locally - that's our idempotency signal. Note that the
#    "claude.ai Atlassian Rovo" entry, if present, is account-attached
#    and invisible to `claude mcp get`; it does not conflict.
if ! claude mcp get "$MCP_NAME" >/dev/null 2>&1; then
    log "registering '$MCP_NAME' MCP at user scope ($MCP_URL)"
    claude mcp add --transport http --scope user "$MCP_NAME" "$MCP_URL"
else
    log "'$MCP_NAME' MCP already registered"
fi

# 4. Verify connection. `claude mcp list` prints one line per server
#    ending in "✓ Connected" or "! Needs authentication". On first
#    registration auth is always required - point the user at /mcp.
mcp_list="$(claude mcp list 2>&1 || true)"
line="$(grep -E "^${MCP_NAME}:" <<<"$mcp_list" || true)"

if [[ -z "$line" ]]; then
    log "warning: '$MCP_NAME' not visible in 'claude mcp list' output"
    log "         (check 'claude mcp list' manually)"
    exit 0
fi

if grep -q "Connected" <<<"$line"; then
    log "'$MCP_NAME' mcp: ✓ Connected"
    exit 0
fi

echo
echo "Atlassian MCP ('$MCP_NAME') needs authentication."
echo "Inside Claude Code:"
echo "  1. run:  claude"
echo "  2. run:  /mcp"
echo "  3. select '$MCP_NAME' and complete the browser OAuth flow"
echo "Then re-run this script to verify."
echo
echo "(The 'claude.ai Atlassian Rovo' entry, if you see it, is the"
echo " account-level Rovo connector with broader scopes. Ignore it, or"
echo " disable it at https://claude.ai/settings/connectors )"

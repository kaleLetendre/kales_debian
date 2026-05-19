#!/usr/bin/env bash
# 31-claude-account.sh - interactive guide for the two Claude Code steps
# that can't be scripted: claude.ai login and Atlassian MCP OAuth.
# Idempotent: when everything is authenticated the script just confirms
# and exits. When something is unfinished it prints clear instructions
# and polls for completion the same way 10-git-and-ssh.sh does for the
# GitHub/Bitbucket key-paste flows.
#
# Why this exists as a bootstrap module: both steps are interactive
# OAuth flows that require running `claude` in another terminal, so they
# can't run inline. But they're load-bearing for the working setup
# (every fresh machine needs Jira/Confluence access), so the bootstrap
# walks the user through them and waits for completion instead of just
# noting them in the README where they'd be forgotten.
#
# About the MCP choice: this registers Atlassian's official Remote MCP
# Server at user scope as 'atlassian'. Both this and the account-level
# 'claude.ai Atlassian Rovo' connector use the same endpoint
# (https://mcp.atlassian.com/v1/mcp) but go through different OAuth
# flows. The Rovo connector requests broad Rovo-agent scopes; a manual
# `claude mcp add` registration goes through its own OAuth with just the
# core Jira/Confluence scopes (search/create/update/comment/transition/
# fetch). That is the lighter-permission path we want. The legacy SSE
# transport at /v1/sse is deprecated and will be removed 2026-06-30.

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

# 2. claude.ai login. .credentials.json is written when /login completes.
#    Poll until it appears so the script auto-advances when the user
#    finishes in the other terminal.
login_ok() { [[ -s "$CREDS" ]]; }

if login_ok; then
    log "claude code is logged in"
else
    echo
    echo "Step 1/2: Claude Code needs to log in to claude.ai."
    echo
    echo "  In a NEW terminal, run:"
    echo "    claude"
    echo "  Then inside Claude Code, run:"
    echo "    /login"
    echo "  Complete the browser flow with the claude.ai account that"
    echo "  owns your Atlassian integration."
    echo
    while ! login_ok; do
        read -r -p "Press Enter once login is complete (Ctrl-C to abort)..." _
    done
    log "claude code is logged in"
fi

# 3. Register the atlassian MCP at user scope (non-interactive). Visible
#    from any working directory once registered. `claude mcp get` exits
#    non-zero when the server isn't registered locally - our idempotency
#    signal. The account-level 'claude.ai Atlassian Rovo' connector is
#    invisible to `mcp get` and does not conflict.
if ! claude mcp get "$MCP_NAME" >/dev/null 2>&1; then
    log "registering '$MCP_NAME' MCP at user scope ($MCP_URL)"
    claude mcp add --transport http --scope user "$MCP_NAME" "$MCP_URL"
else
    log "'$MCP_NAME' MCP already registered"
fi

# 4. Atlassian MCP OAuth. `claude mcp list` prints one line per server
#    ending in "✓ Connected" or "! Needs authentication". Poll the
#    'atlassian:' line until it reports Connected so the script
#    auto-advances after the user completes /mcp auth.
atlassian_connected() {
    local out
    out="$(claude mcp list 2>&1 || true)"
    grep -E "^${MCP_NAME}:.*Connected" <<<"$out" >/dev/null
}

if atlassian_connected; then
    log "'$MCP_NAME' mcp: ✓ Connected"
else
    echo
    echo "Step 2/2: Atlassian MCP ('$MCP_NAME') needs OAuth authentication."
    echo
    echo "  In a NEW terminal (or the same one as before), run:"
    echo "    claude"
    echo "  Then inside Claude Code, run:"
    echo "    /mcp"
    echo "  Select '$MCP_NAME' (NOT 'claude.ai Atlassian Rovo' - that one"
    echo "  is the broad-scope Rovo connector). Complete the browser flow."
    echo
    echo "  When done, exit claude (/quit or Ctrl-C) and return here."
    echo
    while ! atlassian_connected; do
        read -r -p "Press Enter once auth is complete (Ctrl-C to abort)..." _
    done
    log "'$MCP_NAME' mcp: ✓ Connected"
fi

# 5. Note the Rovo connector, in case it bothers the user. Account-tied,
#    so we can't remove it from this script.
if claude mcp list 2>&1 | grep -q "claude.ai Atlassian Rovo"; then
    echo
    log "note: 'claude.ai Atlassian Rovo' is still listed (account-level"
    log "      connector, broader scopes). Disable at:"
    log "        https://claude.ai/settings/connectors"
    log "      if you don't want it. The local '$MCP_NAME' MCP is what"
    log "      Claude Code will use for Jira/Confluence."
fi

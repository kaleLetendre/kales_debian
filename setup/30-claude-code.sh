#!/usr/bin/env bash
# 30-claude-code.sh - install Claude Code from Anthropic's signed apt repo.
# Idempotent. Uses apt (not the curl-bash native installer) so the binary
# lands in /usr/bin, no ~/.local/bin PATH wrangling needed.
#
# Repo + key per https://code.claude.com/docs/en/setup. Expected GPG
# fingerprint pinned in this script; if Anthropic rotates the key, this
# script fails loudly rather than silently trusting a new key.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

KEYRING_DIR="/etc/apt/keyrings"
KEY_PATH="$KEYRING_DIR/claude-code.asc"
LIST_PATH="/etc/apt/sources.list.d/claude-code.list"
KEY_URL="https://downloads.claude.ai/keys/claude-code.asc"
EXPECTED_FPR="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"
REPO_LINE="deb [signed-by=$KEY_PATH] https://downloads.claude.ai/claude-code/apt/stable stable main"

# 1. Keyring directory (apt convention since Debian 12).
if [[ ! -d "$KEYRING_DIR" ]]; then
    log "creating $KEYRING_DIR"
    $SUDO install -d -m 0755 "$KEYRING_DIR"
fi

# 2. Fetch and pin the signing key.
if [[ ! -f "$KEY_PATH" ]]; then
    log "downloading Claude Code signing key"
    $SUDO curl -fsSL "$KEY_URL" -o "$KEY_PATH"
fi

# 3. Verify fingerprint. gpg prints fingerprints with spaces; strip and
#    compare against the pinned value. Bail hard if it doesn't match.
got_fpr="$(gpg --show-keys --with-colons "$KEY_PATH" 2>/dev/null \
    | awk -F: '$1 == "fpr" {print $10; exit}')"
if [[ "$got_fpr" != "$EXPECTED_FPR" ]]; then
    echo "FATAL: Claude Code key fingerprint mismatch." >&2
    echo "  expected: $EXPECTED_FPR" >&2
    echo "  got:      $got_fpr" >&2
    echo "Remove $KEY_PATH and re-run after verifying upstream key rotation." >&2
    exit 1
fi

# 4. Sources list entry.
if [[ ! -f "$LIST_PATH" ]] || ! grep -qF "$REPO_LINE" "$LIST_PATH"; then
    log "writing $LIST_PATH"
    echo "$REPO_LINE" | $SUDO tee "$LIST_PATH" >/dev/null
fi

# 5. Install. apt-get install -y is idempotent.
log "apt update"
$SUDO apt-get update
log "installing claude-code"
$SUDO apt-get install -y claude-code

# 6. Heads-up if a pre-existing native install at ~/.local/bin/claude
#    shadows the apt-installed binary on PATH. Don't auto-delete; that's
#    destructive and the user may have history/sessions tied to it.
if [[ -e "$HOME/.local/bin/claude" ]] && [[ "$(command -v claude || true)" != "/usr/bin/claude" ]]; then
    log "note: ~/.local/bin/claude shadows the apt install on PATH"
    log "      to clean up: rm -f ~/.local/bin/claude && rm -rf ~/.local/share/claude"
fi

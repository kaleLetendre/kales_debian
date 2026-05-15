#!/usr/bin/env bash
# 10-git-and-ssh.sh - git author identity + SSH-to-GitHub. Idempotent.
#
# Bundled because both are prerequisites for "I can push to GitHub" and one
# without the other still leaves the repo's bootstrap promise broken. The
# user-facing pause (paste pubkey into GitHub) only happens on the very
# first run on a given machine.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY="$HOME/.ssh/id_ed25519"
PUB="$KEY.pub"
KNOWN="$HOME/.ssh/known_hosts"

log() { printf "  -> %s\n" "$*"; }

# 1. Git author identity. Only set if missing so a manually-overridden value
#    on this machine is left alone.
if [[ -z "$(git config --global --get user.email 2>/dev/null || true)" ]]; then
    log "setting global git user.email"
    git config --global user.email "kaleletendre@gmail.com"
fi
if [[ -z "$(git config --global --get user.name 2>/dev/null || true)" ]]; then
    log "setting global git user.name"
    git config --global user.name "kaleLetendre"
fi

# 2. SSH dir.
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# 3. Key pair. Comment encodes host + date so multiple machines are
#    distinguishable in the GitHub SSH key list.
if [[ ! -f "$KEY" ]]; then
    log "generating ed25519 key at $KEY"
    ssh-keygen -t ed25519 -C "$(hostname)-$(date +%Y%m%d)" -f "$KEY" -N ""
else
    log "ssh key already exists at $KEY"
fi
chmod 600 "$KEY"
chmod 644 "$PUB"

# 4. Pin github.com in known_hosts so the first connection doesn't stop on
#    the interactive yes/no prompt.
touch "$KNOWN"
chmod 644 "$KNOWN"
if ! ssh-keygen -F github.com -f "$KNOWN" >/dev/null 2>&1; then
    log "adding github.com to known_hosts"
    ssh-keyscan -t rsa,ecdsa,ed25519 github.com 2>/dev/null >> "$KNOWN"
fi

# 5. Test auth. GitHub's SSH endpoint always exits non-zero (no shell), and
#    pipefail would propagate that even when grep matches. So capture output
#    first, discard ssh's exit code, then grep the captured string.
github_auth_ok() {
    local out
    out=$(ssh -o BatchMode=yes \
              -o StrictHostKeyChecking=yes \
              -o ConnectTimeout=5 \
              -T git@github.com 2>&1) || true
    grep -q "successfully authenticated" <<<"$out"
}

if github_auth_ok; then
    log "github ssh auth: OK"
else
    log "github ssh auth: key not yet registered"
    echo
    echo "Add this public key to GitHub:"
    echo "  https://github.com/settings/ssh/new"
    echo
    echo "--- public key ---"
    cat "$PUB"
    echo "--- end ---"
    echo

    # Best-effort: open the browser. Fine if it fails (headless, no DE, etc).
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "https://github.com/settings/ssh/new" >/dev/null 2>&1 || true
    fi

    while ! github_auth_ok; do
        read -r -p "Press Enter after adding the key (Ctrl-C to abort)..." _
    done
    log "github ssh auth: OK"
fi

# 6. If this repo was cloned over HTTPS (README's bootstrap path), flip
#    origin to SSH now that SSH works. No-op on subsequent runs.
if [[ -d "$REPO_DIR/.git" ]]; then
    current_url="$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || true)"
    if [[ "$current_url" == https://github.com/* ]]; then
        new_url="${current_url#https://github.com/}"
        new_url="git@github.com:${new_url%.git}.git"
        log "switching origin from HTTPS to SSH: $new_url"
        git -C "$REPO_DIR" remote set-url origin "$new_url"
    fi
fi

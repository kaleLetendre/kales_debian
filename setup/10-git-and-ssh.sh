#!/usr/bin/env bash
# 10-git-and-ssh.sh - git author identity + SSH-to-GitHub/Bitbucket. Idempotent.
#
# Bundled because both are prerequisites for "I can push to my hosts" and
# one without the other leaves the repo's bootstrap promise broken. The
# user-facing pauses (paste each pubkey into GitHub/Bitbucket) only happen
# on the very first run on a given machine.
#
# Two identities:
#   - Personal: global default. kaleletendre@gmail.com, hosted on GitHub.
#   - Caracal:  applies under ~/caracal/ via git includeIf.
#               kalel@caracal-tech.com, hosted on Bitbucket.
# Two SSH keys, one per host, so personal/work credentials never cross. Both
# keys are regenerated per machine - that is the point of the bootstrap.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"
KNOWN="$SSH_DIR/known_hosts"

GITHUB_KEY="$SSH_DIR/id_ed25519"
CARACAL_KEY="$SSH_DIR/id_ed25519_caracal"

CARACAL_DIR="$HOME/caracal/"
CARACAL_GITCONFIG="$HOME/.gitconfig-caracal"

log() { printf "  -> %s\n" "$*"; }

# 1. Global (personal) git author identity. Only set if missing so a
#    manually-overridden value on this machine is left alone.
if [[ -z "$(git config --global --get user.email 2>/dev/null || true)" ]]; then
    log "setting global git user.email"
    git config --global user.email "kaleletendre@gmail.com"
fi
if [[ -z "$(git config --global --get user.name 2>/dev/null || true)" ]]; then
    log "setting global git user.name"
    git config --global user.name "kaleLetendre"
fi

# 1b. Caracal (work) identity. Anything under ~/caracal/ uses the work
#     email/name via git's includeIf, which points at a side config in $HOME.
#     The side config lives outside the repo because identity is per-machine
#     state. Only set if missing so manual overrides stick.
if [[ -z "$(git config --file "$CARACAL_GITCONFIG" --get user.email 2>/dev/null || true)" ]]; then
    log "writing caracal git user.email"
    git config --file "$CARACAL_GITCONFIG" user.email "kalel@caracal-tech.com"
fi
if [[ -z "$(git config --file "$CARACAL_GITCONFIG" --get user.name 2>/dev/null || true)" ]]; then
    log "writing caracal git user.name"
    git config --file "$CARACAL_GITCONFIG" user.name "Kale Letendre"
fi
# Wire the includeIf into the global config. `git config` dedupes by key, so
# re-running this is a no-op.
git config --global "includeIf.gitdir:${CARACAL_DIR}.path" "$CARACAL_GITCONFIG"

# 2. SSH dir.
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# 3. Key pairs, one per host. The comment encodes host + date + purpose so
#    each machine's keys are distinguishable in the GitHub/Bitbucket UIs.
if [[ ! -f "$GITHUB_KEY" ]]; then
    log "generating ed25519 key at $GITHUB_KEY (personal/github)"
    ssh-keygen -t ed25519 -C "$(hostname)-$(date +%Y%m%d)-github" -f "$GITHUB_KEY" -N ""
else
    log "ssh key already exists at $GITHUB_KEY"
fi
chmod 600 "$GITHUB_KEY"
chmod 644 "$GITHUB_KEY.pub"

if [[ ! -f "$CARACAL_KEY" ]]; then
    log "generating ed25519 key at $CARACAL_KEY (caracal/bitbucket)"
    ssh-keygen -t ed25519 -C "$(hostname)-$(date +%Y%m%d)-caracal" -f "$CARACAL_KEY" -N ""
else
    log "ssh key already exists at $CARACAL_KEY"
fi
chmod 600 "$CARACAL_KEY"
chmod 644 "$CARACAL_KEY.pub"

# 4. SSH config: pin one key per host. `IdentitiesOnly yes` stops ssh-agent
#    from offering every loaded key on every connection (which can lock an
#    account after repeated wrong-key attempts). Sentinel-fenced so re-runs
#    only append once.
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"
if ! grep -q "kales_debian: github" "$SSH_CONFIG"; then
    log "adding github host block to $SSH_CONFIG"
    cat >> "$SSH_CONFIG" <<EOF

# kales_debian: github
Host github.com
    IdentityFile $GITHUB_KEY
    IdentitiesOnly yes
EOF
fi
if ! grep -q "kales_debian: bitbucket" "$SSH_CONFIG"; then
    log "adding bitbucket host block to $SSH_CONFIG"
    cat >> "$SSH_CONFIG" <<EOF

# kales_debian: bitbucket (caracal)
Host bitbucket.org
    IdentityFile $CARACAL_KEY
    IdentitiesOnly yes
EOF
fi

# 5. Pin hosts in known_hosts so the first connection doesn't stop on the
#    interactive yes/no prompt.
touch "$KNOWN"
chmod 644 "$KNOWN"
if ! ssh-keygen -F github.com -f "$KNOWN" >/dev/null 2>&1; then
    log "adding github.com to known_hosts"
    ssh-keyscan -t rsa,ecdsa,ed25519 github.com 2>/dev/null >> "$KNOWN"
fi
if ! ssh-keygen -F bitbucket.org -f "$KNOWN" >/dev/null 2>&1; then
    log "adding bitbucket.org to known_hosts"
    ssh-keyscan -t rsa,ecdsa,ed25519 bitbucket.org 2>/dev/null >> "$KNOWN"
fi

# 6. Test auth and prompt to register the key if the host doesn't recognize
#    it yet. GitHub's SSH endpoint always exits non-zero (no shell), and
#    pipefail would propagate that even when grep matches - so capture the
#    output, swallow ssh's exit code, then grep the captured string.
#    Bitbucket Cloud exits 0 on success but the same defensive pattern works.
github_auth_ok() {
    local out
    out=$(ssh -o BatchMode=yes \
              -o StrictHostKeyChecking=yes \
              -o ConnectTimeout=5 \
              -T git@github.com 2>&1) || true
    grep -q "successfully authenticated" <<<"$out"
}
bitbucket_auth_ok() {
    local out
    out=$(ssh -o BatchMode=yes \
              -o StrictHostKeyChecking=yes \
              -o ConnectTimeout=5 \
              -T git@bitbucket.org 2>&1) || true
    grep -q "authenticated via ssh key" <<<"$out"
}

prompt_for_key() {
    local host="$1" pub="$2" url="$3" check_fn="$4"
    echo
    echo "Add this public key to $host:"
    echo "  $url"
    echo
    echo "--- public key ---"
    cat "$pub"
    echo "--- end ---"
    echo

    # Best-effort: open the browser. Fine if it fails (headless, no DE, etc).
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url" >/dev/null 2>&1 || true
    fi

    while ! "$check_fn"; do
        read -r -p "Press Enter after adding the key to $host (Ctrl-C to abort)..." _
    done
}

if github_auth_ok; then
    log "github ssh auth: OK"
else
    log "github ssh auth: key not yet registered"
    prompt_for_key "GitHub" "$GITHUB_KEY.pub" \
        "https://github.com/settings/ssh/new" github_auth_ok
    log "github ssh auth: OK"
fi

if bitbucket_auth_ok; then
    log "bitbucket ssh auth: OK"
else
    log "bitbucket ssh auth: key not yet registered"
    prompt_for_key "Bitbucket" "$CARACAL_KEY.pub" \
        "https://bitbucket.org/account/settings/ssh-keys/" bitbucket_auth_ok
    log "bitbucket ssh auth: OK"
fi

# 7. If this repo was cloned over HTTPS (README's bootstrap path), flip
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

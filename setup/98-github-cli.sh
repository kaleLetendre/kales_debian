#!/usr/bin/env bash
# 98-github-cli.sh - GitHub CLI (`gh`) from GitHub's official apt repo, then an
# interactive walk-through of `gh auth login`. Idempotent.
#
# Why the upstream repo, not Debian's `gh` package: Debian's tends to lag;
# GitHub's apt repo tracks upstream releases. Same keyring + source-list
# pattern as 93-tailscale.sh.
#
# Note the apt line: `stable main` with NO Debian codename. GitHub's repo is
# distro-agnostic (one pool for all Debian/Ubuntu), so unlike tailscale there's
# no `trixie` to bump here. Architecture is pinned via `dpkg --print-architecture`.
#
# Auth: `gh auth login` is gh's own interactive wizard (account, git protocol,
# browser-or-token). We run it inline only when not already authenticated, so
# re-runs are a no-op. SSH to github.com is already set up by 10-git-and-ssh.sh
# (plus an https->ssh insteadOf rewrite), so `git` push/pull already rides SSH
# regardless -- this login is really about gh's own API token for `gh pr`,
# `gh repo`, etc.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

# Prereqs for fetching the signing key over TLS.
need_pkgs=()
command -v curl >/dev/null 2>&1 || need_pkgs+=(curl)
dpkg -s ca-certificates >/dev/null 2>&1 || need_pkgs+=(ca-certificates)
if (( ${#need_pkgs[@]} > 0 )); then
    log "installing prereqs: ${need_pkgs[*]}"
    $SUDO apt-get update
    $SUDO apt-get install -y "${need_pkgs[@]}"
fi

KEY_PATH="/etc/apt/keyrings/githubcli-archive-keyring.gpg"
LIST_PATH="/etc/apt/sources.list.d/github-cli.list"
KEY_URL="https://cli.github.com/packages/githubcli-archive-keyring.gpg"
LIST_BODY="deb [arch=$(dpkg --print-architecture) signed-by=$KEY_PATH] https://cli.github.com/packages stable main"

sources_changed=0

if [[ ! -s "$KEY_PATH" ]]; then
    log "installing GitHub CLI signing key -> $KEY_PATH"
    $SUDO install -d -m 0755 "$(dirname "$KEY_PATH")"
    # Already a binary keyring (dearmored upstream); no `gpg --dearmor` step.
    curl -fsSL "$KEY_URL" | $SUDO tee "$KEY_PATH" >/dev/null
    $SUDO chmod 0644 "$KEY_PATH"
    sources_changed=1
fi

if [[ ! -f "$LIST_PATH" ]] || ! diff -q <(printf '%s\n' "$LIST_BODY") "$LIST_PATH" >/dev/null 2>&1; then
    log "writing $LIST_PATH"
    printf '%s\n' "$LIST_BODY" | $SUDO tee "$LIST_PATH" >/dev/null
    sources_changed=1
fi

if (( sources_changed )) || ! dpkg -s gh >/dev/null 2>&1; then
    $SUDO apt-get update
fi

if ! dpkg -s gh >/dev/null 2>&1; then
    log "installing gh"
    $SUDO apt-get install -y gh
else
    log "gh already installed"
fi

# Guide through auth. gh keeps its own token separate from git/SSH, so even
# with SSH working, gh itself needs a login for its API-backed commands.
gh_auth_ok() { gh auth status >/dev/null 2>&1; }

if gh_auth_ok; then
    log "gh already authenticated"
else
    echo
    echo "  GitHub CLI needs to authenticate. Launching 'gh auth login'."
    echo "  Suggested answers:"
    echo "    - Account to log into?                 GitHub.com"
    echo "    - Preferred protocol for Git?          SSH  (keys already set by 10-git-and-ssh.sh)"
    echo "    - Authenticate Git with your creds?    Yes"
    echo "    - How would you like to authenticate?  Login with a web browser"
    echo
    # gh's own interactive wizard runs inline here. `|| true` so a Ctrl-C or
    # abort at the prompt doesn't tear the whole bootstrap down under set -e.
    gh auth login || true
    if gh_auth_ok; then
        log "gh authenticated"
    else
        log "gh not authenticated yet - finish later with: gh auth login"
    fi
fi

#!/usr/bin/env bash
# 25-aws-cli.sh - AWS CLI v2 install (official zip). Idempotent.
#
# Why not the apt `awscli` package: that's AWS CLI v1, which is legacy
# and won't get new features (notably the SSO/IAM Identity Center flow
# we use for Caracal). The official installer drops binaries under
# /usr/local/aws-cli/ and symlinks /usr/local/bin/aws -> there.
#
# Credentials are NOT baked into the repo. Per repo CLAUDE.md (no
# secrets in the repo), we instead delegate to `aws configure` on
# first run - it prompts for access key id / secret / region / output
# and writes them to ~/.aws/credentials + ~/.aws/config, which are
# gitignored by being outside the repo entirely. Mirrors the
# GitHub/Bitbucket key prompts in 10-git-and-ssh.sh: blocks once on a
# fresh machine, no-op on every subsequent bootstrap.

set -euo pipefail

SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

# 1. Map uname -m to AWS's release naming. The installer is published
#    only for these two; everything else (armv7, ppc64le, etc.) fails fast.
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  AWS_PKG="awscli-exe-linux-x86_64.zip" ;;
    aarch64) AWS_PKG="awscli-exe-linux-aarch64.zip" ;;
    *)
        echo "ERROR: unsupported arch '$ARCH' for AWS CLI v2 installer" >&2
        exit 1
        ;;
esac

# 2. Install only when missing or when the existing `aws` is v1.
#    We don't auto-upgrade v2 -> latest v2 on every bootstrap (would
#    download ~50MB every run). Force a refresh with AWS_CLI_FORCE=1.
need_install=1
if command -v aws >/dev/null 2>&1; then
    ver="$(aws --version 2>&1 | awk '{print $1}')"
    case "$ver" in
        aws-cli/2.*) need_install=0; log "aws cli already installed: $ver" ;;
        *)           log "aws cli present but not v2 ($ver) - reinstalling" ;;
    esac
fi
if [[ "${AWS_CLI_FORCE:-0}" = "1" ]]; then
    log "AWS_CLI_FORCE=1 - forcing reinstall"
    need_install=1
fi

if [[ $need_install -eq 1 ]]; then
    # unzip is needed to extract the installer payload; not in base-packages.
    if ! command -v unzip >/dev/null 2>&1; then
        log "installing unzip"
        $SUDO apt-get update
        $SUDO apt-get install -y unzip
    fi
    tmp="$(mktemp -d)"
    # shellcheck disable=SC2064  # expand $tmp now, not at trap-fire time
    trap "rm -rf '$tmp'" EXIT
    log "downloading $AWS_PKG"
    curl -fsSL "https://awscli.amazonaws.com/${AWS_PKG}" -o "$tmp/awscliv2.zip"
    unzip -q "$tmp/awscliv2.zip" -d "$tmp"
    # --update lets the installer overwrite an existing v2 in place
    # rather than failing with "already installed at /usr/local/...".
    log "running aws/install --update"
    $SUDO "$tmp/aws/install" --update
    aws --version
fi

# 3. Credentials: prompt only if no default profile is configured yet.
#    `aws configure` handles secret masking, file perms, and the four
#    fields (access key id, secret, region, output) on its own - no
#    point recreating that with `read -s`. The interactive block here
#    is the same pattern as the GitHub/Bitbucket key prompts in
#    10-git-and-ssh.sh; bootstrap is allowed to wait on the user once
#    per machine.
AWS_DIR="$HOME/.aws"
AWS_CREDS="$AWS_DIR/credentials"
mkdir -p "$AWS_DIR"
chmod 700 "$AWS_DIR"
if [[ ! -f "$AWS_CREDS" ]] || ! grep -q '^\[default\]' "$AWS_CREDS"; then
    log "no default profile in $AWS_CREDS - running aws configure"
    echo "  (us-west-2 is the Caracal region; json is the conventional output)"
    aws configure
else
    log "aws default profile already configured in $AWS_CREDS"
fi

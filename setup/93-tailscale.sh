#!/usr/bin/env bash
# 93-tailscale.sh - Tailscale client (outbound-only) from the official
# Tailscale apt repo. Idempotent.
#
# Use case: reach a personal tailnet (e.g. home server) from this
# machine. Not advertising any services back -- after install, bring up
# with `--shields-up` to block incoming connections from other tailnet
# peers:
#
#     sudo tailscale up --shields-up
#
# Local-LAN SSH is unaffected: Tailscale adds a separate 100.64.0.0/10
# CGNAT interface and doesn't capture LAN-range traffic, so SSH to
# 192.168.x.x / 10.x.x.x hosts continues over the local NIC.
#
# First `tailscale up` is browser-interactive for auth, so the script
# stops at installing + starting tailscaled. Subsequent `tailscale up`
# calls are idempotent once the node is registered to the tailnet.
#
# trixie is hard-coded in the apt URL: this repo targets Debian 13 only.
# Bump the codename if/when we move to a newer suite.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

need_pkgs=()
command -v curl >/dev/null 2>&1 || need_pkgs+=(curl)
dpkg -s ca-certificates >/dev/null 2>&1 || need_pkgs+=(ca-certificates)
if (( ${#need_pkgs[@]} > 0 )); then
    log "installing prereqs: ${need_pkgs[*]}"
    $SUDO apt-get update
    $SUDO apt-get install -y "${need_pkgs[@]}"
fi

KEY_PATH="/etc/apt/keyrings/tailscale.gpg"
LIST_PATH="/etc/apt/sources.list.d/tailscale.list"
LIST_BODY="deb [signed-by=$KEY_PATH] https://pkgs.tailscale.com/stable/debian trixie main"
KEY_URL="https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg"

sources_changed=0

if [[ ! -s "$KEY_PATH" ]]; then
    log "installing Tailscale signing key -> $KEY_PATH"
    $SUDO install -d -m 0755 "$(dirname "$KEY_PATH")"
    # .noarmor.gpg is already binary keyring format; no `gpg --dearmor` step.
    curl -fsSL "$KEY_URL" | $SUDO tee "$KEY_PATH" >/dev/null
    $SUDO chmod 0644 "$KEY_PATH"
    sources_changed=1
fi

if [[ ! -f "$LIST_PATH" ]] || ! diff -q <(printf '%s\n' "$LIST_BODY") "$LIST_PATH" >/dev/null 2>&1; then
    log "writing $LIST_PATH"
    printf '%s\n' "$LIST_BODY" | $SUDO tee "$LIST_PATH" >/dev/null
    sources_changed=1
fi

if (( sources_changed )) || ! dpkg -s tailscale >/dev/null 2>&1; then
    $SUDO apt-get update
fi

if ! dpkg -s tailscale >/dev/null 2>&1; then
    log "installing tailscale"
    $SUDO apt-get install -y tailscale
else
    log "tailscale already installed"
fi

# Daemon. The apt postinst enables tailscaled, but be explicit so a re-run
# converges even if someone disabled it manually.
$SUDO systemctl enable --now tailscaled

cat <<'NOTE'

  Tailscale daemon is installed and running. To connect this machine to
  your tailnet in outbound-only mode (incoming peer connections blocked):

      sudo tailscale up --shields-up

  Opens a browser URL once for auth; persists across reboots. LAN SSH is
  unaffected -- Tailscale uses 100.64.0.0/10 and doesn't capture LAN.

NOTE

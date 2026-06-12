#!/usr/bin/env bash
# server/10-tailscale-ssh.sh - make this box reachable as
#   ssh <you>@homeserver.tailf19ac6.ts.net
# (<you> is whatever OS user you create at install time), reproducing the
# live server's actual config. Idempotent. Runs only under the `server`
# role (see bootstrap.sh's role menu).
#
# How SSH-in really works here (confirmed against the running server):
#   - Plain OpenSSH (sshd) on port 22 answers the connection. Tailscale's
#     own SSH is OFF on the server (prefs RunSSH=false) -- so we deliberately
#     do NOT pass --ssh. Tailscale only provides the network + MagicDNS name.
#   - The node joins the tailnet as hostname `homeserver` with shields DOWN
#     (prefs ShieldsUp=false) so peers are allowed to open the sshd port.
#   - The tailnet domain (tailf19ac6.ts.net) is fixed by the account; the
#     `homeserver` half is set by --hostname below.
#   - Debian's openssh-server allows password auth out of the box, which is
#     how the server is reached today -- no sshd_config edits needed to match.
#
# Contrast with setup/93-tailscale.sh: that installs Tailscale for the
# *client* (laptop) and documents bringing it up with --shields-up (outbound
# only). The server runs all of setup/ first -- so Tailscale is already
# installed by the time this layer runs -- then brings it up in the opposite,
# incoming-allowed mode.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

TS_HOSTNAME="homeserver"

# 1. OpenSSH server -- this is what actually answers the SSH connection.
#    The client setup only manages SSH *keys* (setup/10-git-and-ssh.sh); the
#    daemon is a server-only concern, so it lives here.
if ! dpkg -s openssh-server >/dev/null 2>&1; then
    log "installing openssh-server"
    $SUDO apt-get update
    $SUDO apt-get install -y openssh-server
else
    log "openssh-server already installed"
fi
# On Debian the service is named `ssh`. Enable + start so it survives reboots.
$SUDO systemctl enable --now ssh

# 2. Tailscale must already be installed by setup/93-tailscale.sh, which runs
#    earlier (server runs the full setup/ first). Fail loudly if it isn't,
#    rather than silently skipping the thing that makes the box reachable.
if ! command -v tailscale >/dev/null 2>&1; then
    echo "ERROR: tailscale not installed. Run the full bootstrap first" >&2
    echo "       (setup/93-tailscale.sh installs it) before the server layer." >&2
    exit 1
fi
$SUDO systemctl enable --now tailscaled

# 3. Join the tailnet as `homeserver`, shields down (incoming allowed).
#    `tailscale up` is declarative: flags left unspecified revert to their
#    defaults, which here is exactly the server's prefs (ShieldsUp=false,
#    RunSSH=false). The FIRST run on a fresh machine opens a browser URL once
#    to authenticate; afterwards the node key is valid and this returns
#    immediately, so it's safe to re-run.
log "bringing Tailscale up as '$TS_HOSTNAME' (first run opens a browser to log in)"
$SUDO tailscale up --hostname="$TS_HOSTNAME"

# 4. Match the live server's auto-update pref (prefs AutoUpdate.Apply=true):
#    let Tailscale update itself so an unattended box doesn't drift.
$SUDO tailscale set --auto-update

log "done -- reachable at: ssh $(whoami)@$TS_HOSTNAME.tailf19ac6.ts.net"

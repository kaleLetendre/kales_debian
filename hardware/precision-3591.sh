#!/usr/bin/env bash
# hardware/precision-3591.sh - Dell Precision 3591 (work laptop).
# Selected automatically by bootstrap.sh via /sys/class/dmi/id/product_name.
# Idempotent.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

# Kernel headers FIRST. DKMS will not build the NVIDIA module without them,
# and the failure is silent if headers show up afterwards.
log "linux-headers-amd64"
$SUDO apt-get install -y linux-headers-amd64

# Intel BE200/BE201 Wi-Fi firmware. Supported by kernel 6.12 (Trixie).
log "firmware-iwlwifi"
$SUDO apt-get install -y firmware-iwlwifi

# NVIDIA hybrid graphics via PRIME render offload.
# Open kernel module is the recommended path for Ada-generation cards.
# Never use NVIDIA's .run installer here, it fights DKMS.
log "nvidia driver (open kernel module)"
$SUDO apt-get install -y nvidia-open-kernel-dkms nvidia-driver

# prime-run wrapper: iGPU drives the display, dGPU spins up on demand.
if [[ ! -x /usr/local/bin/prime-run ]]; then
    log "installing /usr/local/bin/prime-run"
    $SUDO tee /usr/local/bin/prime-run >/dev/null <<'EOF'
#!/usr/bin/env bash
# Run a command on the NVIDIA GPU via PRIME render offload.
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia exec "$@"
EOF
    $SUDO chmod +x /usr/local/bin/prime-run
fi

# Dell firmware updates via LVFS. Dell supports fwupd well.
log "fwupd"
$SUDO apt-get install -y fwupd
$SUDO fwupdmgr refresh --force || true

# Fingerprint reader. Most Dell variants work out of the box.
# Verify with `lsusb` on first boot, some Goodix chips need extra work.
log "fprintd"
$SUDO apt-get install -y fprintd libpam-fprintd

#=============================================================================
# Tailscale SSH: make this laptop reachable from the tailnet
#=============================================================================
# This laptop is a `client` (outbound-only by default) that we also want to
# reach by SSH from other tailnet nodes. We use Tailscale's built-in SSH here,
# NOT the plain-sshd approach in server/10-tailscale-ssh.sh (which reproduces
# the homeserver). Why Tailscale SSH for a laptop:
#   - No openssh-server: tailscaled itself answers SSH, and only over the
#     tailscale interface -- nothing listens on the LAN/Wi-Fi NIC, so there's
#     no port-22 exposure off-tailnet and no password-auth surface.
#   - Who may connect is governed by the tailnet ACL policy, not local keys.
#     A personal tailnet's default policy already permits SSH to your own
#     devices; a locked-down custom policy needs an `ssh` rule allowing it.
#
# Unavoidable tradeoff (confirmed against Tailscale's docs): being reachable
# requires shields DOWN. `--shields-up` blocks ALL incoming tailnet
# connections, Tailscale SSH included -- so we turn it off here, reversing the
# outbound-only posture setup/93-tailscale.sh documents. Net new reachable
# surface is Tailscale SSH (ACL-gated) plus ICMP ping, over the tailnet only.
#
# `tailscale set` is declarative + idempotent and tweaks a running tailscaled
# without re-auth, so re-running bootstrap is a no-op once applied. We install
# no openssh-server, so enabling Tailscale SSH raises no port-22 conflict and
# no --accept-risk prompt.
if ! command -v tailscale >/dev/null 2>&1; then
    echo "ERROR: tailscale not installed (setup/93-tailscale.sh). Run the full" >&2
    echo "       bootstrap so Tailscale is present before this hardware layer." >&2
    exit 1
fi
log "enabling Tailscale SSH + dropping shields (incoming allowed over tailnet)"
$SUDO tailscale set --ssh --shields-up=false

# Best-effort reach target. `2>/dev/null` + the if-guard keep a not-yet-joined
# node (logged out -> no Self.DNSName) from aborting the run under set -e.
if reach=$(tailscale status --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' 2>/dev/null) && [[ -n "$reach" ]]; then
    log "reachable from the tailnet at: ssh $(whoami)@$reach"
else
    log "enabled; if not joined yet run 'sudo tailscale up', then see 'tailscale status' for the name"
fi

# More 3591-specific tweaks (TLP, brightness quirks, etc.) go here later.

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

# More 3591-specific tweaks (TLP, brightness quirks, etc.) go here later.

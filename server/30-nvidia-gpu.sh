#!/usr/bin/env bash
# server/30-nvidia-gpu.sh - NVIDIA driver + firmware for the server's desktop
# GPU (GeForce GTX 1080, GP104 / Pascal). Idempotent. No-op on a box without
# an NVIDIA GPU, so it is safe if the server ever moves to other hardware.
#
# Debian's proprietary `nvidia-driver` (DKMS), NOT the open kernel module the
# Precision laptop uses: NVIDIA's open module only supports Turing (GTX 16xx /
# RTX 20xx) and newer, and Pascal predates that. Never NVIDIA's .run driver,
# it fights DKMS.
#
# linux-headers-amd64 MUST land before nvidia-driver, or DKMS has nothing to
# build the module against and fails silently (the driver "installs" but
# nvidia.ko never appears). Needs contrib/non-free (setup/05-apt-components.sh).
#
# firmware-misc-nonfree - GSP/misc firmware blobs the nvidia stack loads
# firmware-realtek      - the X570 board's Realtek NIC/audio firmware; also
#                         what the Alfa RTL8814AU (server/20) leans on

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

log "Realtek firmware"
$SUDO apt-get install -y firmware-realtek

# 10de = NVIDIA's PCI vendor id; class 03xx = display controller.
if ! lspci -nd 10de: | grep -q ' 03'; then
    log "no NVIDIA GPU found, skipping driver"
    exit 0
fi

log "kernel headers (before nvidia, for DKMS)"
$SUDO apt-get install -y linux-headers-amd64

log "nvidia-driver + firmware"
$SUDO apt-get install -y nvidia-driver firmware-misc-nonfree

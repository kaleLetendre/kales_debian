#!/usr/bin/env bash
# 38-virt-manager.sh - KVM/QEMU virtual machines with a GUI. Idempotent.
#
# First use: a throwaway Windows 11 VM to run the Xbox Accessories app,
# the only way to update Xbox controller firmware (no Linux updater
# exists). Old firmware (BLE 5.09) pairs fine over Bluetooth but loops on
# every reconnect. Useful beyond that for any "needs Windows once" job.
#
#   qemu-system-x86       - the hypervisor (uses /dev/kvm for hardware virt)
#   libvirt-daemon-system - libvirtd + the qemu:///system connection
#   virt-manager          - GUI: create VMs, attach USB devices (passthrough)
#   ovmf                  - UEFI firmware; Windows 11 requires UEFI
#   swtpm swtpm-tools     - software TPM 2.0; Windows 11 setup refuses
#                           to install without a TPM
#   qemu-utils            - qemu-img, for creating/inspecting disk images

set -euo pipefail

log() { printf "  -> %s\n" "$*"; }

sudo apt-get install -y qemu-system-x86 qemu-utils libvirt-daemon-system \
    virt-manager ovmf swtpm swtpm-tools

sudo systemctl enable --now libvirtd.service

# libvirt group = manage qemu:///system VMs without a polkit password
# prompt each time. Takes effect at next login; until then virt-manager
# just asks for the password. kvm group = direct /dev/kvm access.
for grp in libvirt kvm; do
    if id -nG "$USER" | tr ' ' '\n' | grep -qx "$grp"; then
        log "$USER already in $grp"
    else
        log "adding $USER to $grp (effective next login)"
        sudo usermod -aG "$grp" "$USER"
    fi
done

# libvirt's NAT network ("default") gives VMs internet access. It ships
# defined but not autostarted; `net-autostart` is idempotent, `net-start`
# errors if already active, hence the guard.
if ! sudo virsh net-info default 2>/dev/null | grep -q '^Active:.*yes'; then
    log "starting libvirt default network"
    sudo virsh net-start default
fi
sudo virsh net-autostart default

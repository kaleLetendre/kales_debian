#!/usr/bin/env bash
# server/40-tpm-luks-unlock.sh - unlock the LUKS disks from the TPM at boot
# (clevis), so the headless server comes back after a power cut without
# someone typing the passphrase at the console. Idempotent.
#
# clevis-luks      - binds a LUKS keyslot to a clevis "pin"
# clevis-tpm2      - the TPM2 pin: the key is sealed to the TPM's PCR state
# clevis-initramfs - hook that runs the unlock inside the initramfs
# tpm2-tools       - inspect the TPM (tpm2_pcrread) when debugging
#
# Bound with NO PCRs ('{}' -> clevis defaults: sha256, ecc key), matching the
# live server (`clevis luks list` shows no pcr_ids). The TPM releases the key
# to whatever boots on this motherboard, so firmware, kernel and GRUB updates
# never break auto-unlock. PCR 7 would add nothing here anyway: the server
# runs with Secure Boot disabled (firmware in Setup Mode), and PCR 7 then
# reads the same "SB off" for every boot, including a live USB.
#
# Threat model: this setup protects against the DRIVE being stolen on its own.
# It is deliberately low-friction, not high-security. If the whole MACHINE is
# taken, it auto-unlocks for the thief too, and any OS booted on it (e.g. a
# live USB) can ask the TPM for the key.
#
# Hardening, if this is ever reused somewhere that matters (roughly in order
# of value vs hassle):
#   1. Firmware: set a BIOS/UEFI admin password, disable USB/network boot,
#      lock the boot order. Without this, PCR choices can be worked around
#      by changing boot settings.
#   2. Turn Secure Boot on (enroll keys, leave Setup Mode), then bind to
#      PCRs: '{"pcr_ids":"0,2,4,7,8,9"}'
#        0/2 firmware code + option ROMs, 4 bootloader + kernel EFI images,
#        8 GRUB commands + kernel cmdline (blocks `init=/bin/bash` edits),
#        9 kernel + initrd GRUB loaded (blocks a live USB's own initrd).
#      Cost: every kernel, GRUB or BIOS update changes 4/8/9 (and 0), so
#      auto-unlock fails until re-sealed. Type the passphrase once after
#      the update, then: sudo clevis luks regen -d <dev> -s <slot>
#   3. Set a GRUB superuser password so the boot menu/cmdline can't be
#      edited (complements PCR 8).
#   4. Require something besides the TPM: use clevis's `sss` pin to need
#      tpm2 AND a Tang server on the home network (machine taken off-site
#      won't unlock), or switch to `systemd-cryptenroll --tpm2-with-pin`
#      for TPM + PIN at boot.
#   5. Test what a failed or interrupted boot does after the disk is
#      unlocked: if it drops to an emergency/root shell, the data is open.
#      Lock root (passwd -l root) so systemd's emergency mode asks for a
#      password that doesn't exist.
#
# Binding asks for the existing LUKS passphrase once per disk; already-bound
# disks are skipped. Devices come from /etc/crypttab so nothing here names
# this machine's UUIDs.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

if [[ ! -e /dev/tpmrm0 ]]; then
    log "no TPM device, skipping"
    exit 0
fi

log "clevis + tpm2 packages"
$SUDO apt-get install -y clevis clevis-luks clevis-tpm2 clevis-initramfs tpm2-tools

[[ -f /etc/crypttab ]] || { log "no /etc/crypttab, nothing to bind"; exit 0; }

changed=0
# crypttab: <name> <device> <keyfile> <options>; device is usually UUID=...
while read -r name dev _rest; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    [[ "$dev" == UUID=* ]] && dev="/dev/disk/by-uuid/${dev#UUID=}"
    if [[ -n "$($SUDO clevis luks list -d "$dev" 2>/dev/null)" ]]; then
        log "$name already bound"
        continue
    fi
    log "binding $name ($dev) to TPM2 (no PCRs) -- enter its LUKS passphrase"
    $SUDO clevis luks bind -d "$dev" tpm2 '{}'
    changed=1
done < /etc/crypttab

if (( changed )); then
    log "rebuilding initramfs so the unlock hook sees the new bindings"
    $SUDO update-initramfs -u -k all
fi

#!/usr/bin/env bash
# server/20-alfa-wifi.sh - move the server's Wi-Fi onto the Alfa USB adapter
# (Realtek RTL8814AU, 0bda:8813) and switch the onboard Intel Wi-Fi off.
# Idempotent. No-op on a machine without the adapter plugged in.
#
# Why: the onboard Intel AC 3168 is a Wi-Fi + Bluetooth combo card sharing
# ONE 2.4 GHz radio/antenna. With Wi-Fi active on it, a Bluetooth headset
# (WH-CH720N) dropped A2DP every ~267 s (wireplumber "error 24" / "Failure
# in Bluetooth audio transport"), and neither the BT autosuspend fix in
# setup/85-bluetooth.sh nor pinning the Wi-Fi BSSID stopped it. Putting
# Wi-Fi on a separate radio leaves the Intel card to Bluetooth alone.
#
# Steps:
#   1. Build the out-of-tree rtl8814au driver with DKMS (Debian 6.12 has no
#      in-kernel driver for this chip).
#   2. Clone the Wi-Fi profile active on the Intel card onto the Alfa,
#      bring it up, and verify it reaches the internet.
#   3. Only after that works: mark iwlwifi Wi-Fi unmanaged and link it down
#      (stops all scanning; Bluetooth on the same card is unaffected).
#   4. Install a boot-time fallback: if the Alfa isn't online ~90 s after
#      boot (driver failed to build for a new kernel, adapter unplugged),
#      hand the Intel card back to NetworkManager. This box is Wi-Fi only
#      and LUKS/TPM auto-unlocks unattended, so without this a broken
#      driver after a kernel update = unreachable server.
#
# Driver source: morrownr/8814au, pinned to 8d82854 (2025-09), the original
# maintainer's last commit; supports kernels up to 6.14. Later commits come
# from a third-party fork merge -- not taken without review. Bump the pin
# deliberately (and re-read the diff) if a newer kernel needs it.
#
# Undo: sudo rm /etc/NetworkManager/conf.d/90-intel-wifi-unmanaged.conf,
#   sudo systemctl reload NetworkManager, nmcli device connect <intel iface>.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

USB_ID="0bda:8813"
DRV_PKG="rtl8814au"
DRV_VER="5.8.5.1"          # PACKAGE_VERSION from the pinned dkms.conf
DRV_COMMIT="8d82854"
DRV_REPO="https://github.com/morrownr/8814au.git"
DRV_SRC="/usr/src/${DRV_PKG}-${DRV_VER}"
NM_UNMANAGED_CONF=/etc/NetworkManager/conf.d/90-intel-wifi-unmanaged.conf
FALLBACK_BIN=/usr/local/sbin/alfa-wifi-fallback
FALLBACK_UNIT=/etc/systemd/system/alfa-wifi-fallback.service

if ! lsusb -d "$USB_ID" >/dev/null; then
    log "Alfa RTL8814AU ($USB_ID) not plugged in; skipping"
    exit 0
fi

# Prints the interface name of the first Wi-Fi netdev bound to driver $1.
iface_for_driver() {
    local d
    for d in /sys/class/net/*; do
        [[ -d "$d/wireless" || -d "$d/phy80211" ]] || continue
        [[ "$(basename "$(readlink -f "$d/device/driver")")" == "$1" ]] || continue
        basename "$d"
        return 0
    done
    return 1
}

# --- 1. driver -------------------------------------------------------------
# linux-headers-amd64 tracks the running kernel flavour so DKMS rebuilds on
# every kernel upgrade (missing headers = DKMS silently builds nothing).
$SUDO apt-get install -y dkms build-essential git linux-headers-amd64 \
    "linux-headers-$(uname -r)"

if [[ ! -d "$DRV_SRC/.git" ]]; then
    log "fetching driver source @ $DRV_COMMIT"
    $SUDO rm -rf "$DRV_SRC"
    $SUDO git clone -q "$DRV_REPO" "$DRV_SRC"
fi
if [[ "$($SUDO git -C "$DRV_SRC" rev-parse --short=7 HEAD)" != "$DRV_COMMIT" ]]; then
    $SUDO git -C "$DRV_SRC" checkout -q "$DRV_COMMIT"
fi
# Upstream's recommended module options (USB mode switch off, LED on).
$SUDO install -m 644 "$DRV_SRC/8814au.conf" /etc/modprobe.d/8814au.conf

# `dkms add` errors if the module/version is already registered.
if ! $SUDO dkms status -m "$DRV_PKG" -v "$DRV_VER" | grep -q .; then
    $SUDO dkms add -m "$DRV_PKG" -v "$DRV_VER"
fi
# Build for every installed kernel that has headers, not just the running
# one: a kernel upgrade installed *before* this module was added (pending
# reboot) never triggers DKMS for it, and booting it would leave no Alfa
# driver (the fallback below would kick in, but BT audio drops come back).
for kdir in /lib/modules/*/build; do
    # build is a symlink into the headers package; dangling = no headers.
    [[ -d "$kdir" ]] || continue
    kver="$(basename "$(dirname "$kdir")")"
    if $SUDO dkms status -m "$DRV_PKG" -v "$DRV_VER" -k "$kver" | grep -q installed; then
        log "$DRV_PKG already built for $kver"
        continue
    fi
    log "building $DRV_PKG for $kver (a few minutes)"
    $SUDO dkms install -m "$DRV_PKG" -v "$DRV_VER" -k "$kver"
done
$SUDO modprobe 8814au
# The driver registers the netdev as wlan0 and udev renames it to the
# predictable wlx<mac> a moment later; wait for that or we'd bind the
# profile to a name that no longer exists.
$SUDO udevadm settle

alfa_if=""
for _ in $(seq 1 20); do
    if alfa_if="$(iface_for_driver rtl8814au)"; then break; fi
    sleep 1
done
if [[ -z "$alfa_if" ]]; then
    echo "driver loaded but no Alfa Wi-Fi interface appeared" >&2
    exit 1
fi
log "Alfa interface: $alfa_if"

# --- 2. move the Wi-Fi profile onto the Alfa --------------------------------
alfa_con="$(nmcli -g NAME,DEVICE connection show --active | awk -F: -v d="$alfa_if" '$2==d{print $1}')"
if [[ -z "$alfa_con" ]]; then
    intel_if="$(iface_for_driver iwlwifi || true)"
    src_con=""
    if [[ -n "$intel_if" ]]; then
        src_con="$(nmcli -g GENERAL.CONNECTION device show "$intel_if")"
    fi
    if [[ -n "$src_con" ]]; then
        alfa_con="${src_con}-alfa"
    else
        # Intel already off (re-run) and the Alfa profile exists but is down.
        alfa_con="$(nmcli -g NAME connection show | grep -- '-alfa$' | head -n1 || true)"
    fi
    if [[ -z "$alfa_con" ]]; then
        echo "no active Wi-Fi profile to copy onto $alfa_if" >&2
        exit 1
    fi
    if ! nmcli -g NAME connection show | grep -qx -- "$alfa_con"; then
        log "cloning Wi-Fi profile '$src_con' -> '$alfa_con'"
        # clone copies the PSK too; needs root to read the secret.
        $SUDO nmcli connection clone "$src_con" "$alfa_con"
    fi
    # Bind to the Alfa, drop any BSSID pin (the old coex workaround, not
    # needed on a dedicated radio), and prefer it over the Intel profile.
    $SUDO nmcli connection modify "$alfa_con" \
        connection.interface-name "$alfa_if" \
        802-11-wireless.bssid "" \
        connection.autoconnect yes \
        connection.autoconnect-priority 10
    if [[ -n "$src_con" ]]; then
        # Keep the original as the Intel-only fallback profile.
        $SUDO nmcli connection modify "$src_con" \
            connection.interface-name "$intel_if" \
            802-11-wireless.bssid ""
    fi
    log "bringing up '$alfa_con' on $alfa_if"
    $SUDO nmcli connection up "$alfa_con"
fi

# Verify before touching the Intel card: a real round trip out of the Alfa.
if ! ping -c 3 -W 3 -I "$alfa_if" 1.1.1.1 >/dev/null; then
    echo "$alfa_if is up but can't reach the internet; leaving Intel Wi-Fi on" >&2
    exit 1
fi
log "$alfa_if online"

# --- 3. switch the Intel Wi-Fi off ------------------------------------------
# Matched by driver, not interface name. Unmanaged = NM never scans or
# connects on it. The link-down stops anything else from using the radio.
NM_CONF_CONTENT='# server/20-alfa-wifi.sh: Wi-Fi runs on the Alfa; leave the Intel radio to Bluetooth.
[keyfile]
unmanaged-devices=driver:iwlwifi'
if [[ "$(cat "$NM_UNMANAGED_CONF" 2>/dev/null)" != "$NM_CONF_CONTENT" ]]; then
    log "marking Intel (iwlwifi) Wi-Fi unmanaged"
    printf '%s\n' "$NM_CONF_CONTENT" | $SUDO tee "$NM_UNMANAGED_CONF" >/dev/null
    $SUDO nmcli general reload conf
fi
intel_if="$(iface_for_driver iwlwifi || true)"
if [[ -n "$intel_if" ]]; then
    # Runtime-unmanage too: the conf only applies to devices as they appear.
    $SUDO nmcli device set "$intel_if" managed no
    $SUDO ip link set "$intel_if" down
    log "$intel_if down"
fi

# --- 4. boot-time fallback to the Intel card ---------------------------------
$SUDO tee "$FALLBACK_BIN" >/dev/null <<'EOF'
#!/usr/bin/env bash
# Installed by kales_debian server/20-alfa-wifi.sh. If the Alfa Wi-Fi isn't
# online 90 s after boot, re-enable the Intel Wi-Fi so the server stays
# reachable (Wi-Fi-only box). Bluetooth audio may drop again until fixed.
for _ in $(seq 1 90); do
    for d in /sys/class/net/*; do
        [[ "$(basename "$(readlink -f "$d/device/driver")")" == rtl8814au ]] || continue
        if [[ "$(cat "$d/operstate")" == up ]] && nmcli -g IP4.ADDRESS device show "$(basename "$d")" | grep -q .; then
            exit 0
        fi
    done
    sleep 1
done
echo "Alfa Wi-Fi not online after 90s; falling back to Intel Wi-Fi"
for d in /sys/class/net/*; do
    [[ "$(basename "$(readlink -f "$d/device/driver")")" == iwlwifi ]] || continue
    i="$(basename "$d")"
    ip link set "$i" up
    nmcli device set "$i" managed yes
    nmcli device connect "$i"
done
EOF
$SUDO chmod 755 "$FALLBACK_BIN"
$SUDO tee "$FALLBACK_UNIT" >/dev/null <<EOF
[Unit]
Description=Fall back to Intel Wi-Fi if the Alfa adapter isn't online
After=NetworkManager.service
Wants=NetworkManager.service

[Service]
Type=oneshot
ExecStart=$FALLBACK_BIN

[Install]
WantedBy=multi-user.target
EOF
$SUDO systemctl daemon-reload
$SUDO systemctl enable alfa-wifi-fallback.service >/dev/null
log "boot fallback installed ($FALLBACK_UNIT)"

#!/usr/bin/env bash
# 78-vscode-keyring.sh - make gnome-keyring usable on XFCE, then tell
# VS Code to use it. Idempotent.
#
# Two problems on a fresh Debian XFCE install:
#
#   1. /etc/xdg/autostart/gnome-keyring-{secrets,pkcs11,ssh}.desktop all
#      have `OnlyShowIn=GNOME;Unity;MATE;` -- XFCE is not listed, so
#      none of them autostart. pam_gnome_keyring's auto_start launches
#      *a* daemon, but without the autostart's `--start` integration the
#      login keyring is never unlocked, so libsecret can't access it.
#
#   2. VS Code (Electron) uses XDG_CURRENT_DESKTOP to pick a backend.
#      On XFCE it falls through to "basic" (plaintext) and pops up
#      "OS keyring is not available" on launch.
#
# Fix 1: copy the autostart files into ~/.config/autostart/ with XFCE
# added to OnlyShowIn. User-level overrides take precedence over the
# system files, so no /etc edits needed.
# Fix 2: write ~/.config/Code/argv.json with password-store=gnome-libsecret
# so VS Code skips detection and uses libsecret directly.
#
# Both take effect on next login (the daemon needs to start under the
# new autostart entries so PAM can hand off the unlock password).

set -euo pipefail

log() { printf "  -> %s\n" "$*"; }

# --- Fix 1: gnome-keyring autostart on XFCE ----------------------------

SYS_AUTOSTART="/etc/xdg/autostart"
USER_AUTOSTART="$HOME/.config/autostart"
mkdir -p "$USER_AUTOSTART"

for component in pkcs11 secrets ssh; do
    src="$SYS_AUTOSTART/gnome-keyring-$component.desktop"
    dst="$USER_AUTOSTART/gnome-keyring-$component.desktop"
    [[ -f "$src" ]] || { log "$src missing; skipping"; continue; }

    # Build the patched body: add XFCE to OnlyShowIn if not already there.
    body="$(sed -E '/^OnlyShowIn=/{ /XFCE/!s/$/XFCE;/ }' "$src")"

    if [[ -f "$dst" ]] && diff -q <(printf '%s\n' "$body") "$dst" >/dev/null 2>&1; then
        log "$dst already current"
    else
        log "writing $dst (adds XFCE to OnlyShowIn)"
        printf '%s\n' "$body" > "$dst"
    fi
done

# --- Fix 2: VS Code password-store -------------------------------------

CODE_CFG_DIR="$HOME/.config/Code"
CODE_ARGV="$CODE_CFG_DIR/argv.json"

read -r -d '' CODE_BODY <<'EOF' || true
// Managed by kales_debian/setup/78-vscode-keyring.sh. Edit there, not here.
// gnome-libsecret routes secret storage through libsecret/gnome-keyring,
// bypassing Electron's XDG_CURRENT_DESKTOP-based auto-detection that
// falls through on XFCE.
{
    "password-store": "gnome-libsecret"
}
EOF

if [[ -f "$CODE_ARGV" ]] && grep -q '"password-store"' "$CODE_ARGV"; then
    log "$CODE_ARGV already has a password-store setting"
else
    log "writing $CODE_ARGV"
    mkdir -p "$CODE_CFG_DIR"
    printf '%s\n' "$CODE_BODY" > "$CODE_ARGV"
fi

log "log out + back in (or reboot) so the new autostart entries take effect"

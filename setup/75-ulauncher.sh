#!/usr/bin/env bash
# 75-ulauncher.sh - install ulauncher (search-bar app launcher, similar
# to Ubuntu/GNOME's super-key dash) and wire it up so tapping the Super
# key alone toggles it. Idempotent.
#
# Mechanism:
#   - ulauncher provides `ulauncher-toggle` which shows/hides the launcher.
#   - Super is a modifier, so by itself it doesn't fire a keypress event.
#     xcape watches Super_L; when it's released without any other key in
#     between, it synthesizes <Super>F12.
#   - XFCE binds <Super>F12 -> `ulauncher-toggle`.
#
# Holding Super for chords (Super+r, Super+Tab, tiling, etc.) still works
# because xcape only fires on tap-and-release with no other key pressed.
#
# ulauncher isn't in Debian's repos; we fetch the latest .deb from the
# upstream GitHub release.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

need_pkgs=()
command -v curl >/dev/null 2>&1 || need_pkgs+=(curl)
command -v xcape >/dev/null 2>&1 || need_pkgs+=(xcape)
dpkg -s ca-certificates >/dev/null 2>&1 || need_pkgs+=(ca-certificates)
if (( ${#need_pkgs[@]} > 0 )); then
    log "installing prereqs: ${need_pkgs[*]}"
    $SUDO apt-get update
    $SUDO apt-get install -y "${need_pkgs[@]}"
fi

# Install ulauncher from upstream .deb if not already installed.
if ! dpkg -s ulauncher >/dev/null 2>&1; then
    log "fetching latest ulauncher .deb url from GitHub"
    deb_url="$(curl -fsSL https://api.github.com/repos/Ulauncher/Ulauncher/releases/latest \
        | grep -oE 'https://[^"]*ulauncher_[0-9.]+_all\.deb' | head -1)"
    if [[ -z "$deb_url" ]]; then
        echo "could not find ulauncher .deb in latest release" >&2
        exit 1
    fi
    log "downloading $deb_url"
    tmpdeb="$(mktemp --suffix=.deb)"
    trap 'rm -f "$tmpdeb"' EXIT
    curl -fsSL "$deb_url" -o "$tmpdeb"
    log "installing ulauncher"
    # apt handles deps from the .deb file directly (modern apt).
    $SUDO apt-get install -y "$tmpdeb"
else
    log "ulauncher already installed"
fi

# Bind <Super>F12 to ulauncher-toggle.
KEY="/commands/custom/<Super>F12"
CMD="ulauncher-toggle"
current="$(xfconf-query -c xfce4-keyboard-shortcuts -p "$KEY" 2>/dev/null || true)"
if [[ "$current" != "$CMD" ]]; then
    log "binding <Super>F12 -> $CMD"
    xfconf-query -c xfce4-keyboard-shortcuts -p "$KEY" \
        --create --type string --set "$CMD"
else
    log "<Super>F12 already bound to $CMD"
fi

# Persist xcape and ulauncher across logins via XDG autostart.
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

write_autostart() {
    local path="$1" body="$2"
    if [[ ! -f "$path" ]] || ! diff -q <(printf '%s\n' "$body") "$path" >/dev/null 2>&1; then
        log "writing $path"
        printf '%s\n' "$body" > "$path"
    else
        log "$path already current"
    fi
}

read -r -d '' XCAPE_AUTOSTART <<'EOF' || true
[Desktop Entry]
Type=Application
Name=xcape (Super tap = ulauncher)
Comment=Managed by kales_debian/setup/75-ulauncher.sh. Edit there, not here.
Exec=xcape -e "Super_L=Super_L|F12"
X-GNOME-Autostart-enabled=true
NoDisplay=true
Terminal=false
EOF
write_autostart "$AUTOSTART_DIR/xcape-super.desktop" "$XCAPE_AUTOSTART"

read -r -d '' ULAUNCHER_AUTOSTART <<'EOF' || true
[Desktop Entry]
Type=Application
Name=ulauncher
Comment=Managed by kales_debian/setup/75-ulauncher.sh. Edit there, not here.
Exec=ulauncher --hide-window
X-GNOME-Autostart-enabled=true
NoDisplay=true
Terminal=false
EOF
write_autostart "$AUTOSTART_DIR/ulauncher.desktop" "$ULAUNCHER_AUTOSTART"

# Apply now: start xcape and ulauncher for the running session so no
# logout/login needed.
if [[ -n "${DISPLAY:-}" ]]; then
    if ! pgrep -x xcape >/dev/null 2>&1; then
        log "starting xcape for current session"
        nohup xcape -e 'Super_L=Super_L|F12' >/dev/null 2>&1 &
        disown 2>/dev/null || true
    else
        log "xcape already running"
    fi
    # Match only the actual /usr/bin/ulauncher daemon, not a script whose
    # filename happens to contain "ulauncher" (e.g. this one).
    if ! pgrep -f '(^|/)ulauncher( |$)' >/dev/null 2>&1; then
        log "starting ulauncher daemon for current session"
        nohup ulauncher --hide-window >/dev/null 2>&1 &
        disown 2>/dev/null || true
    else
        log "ulauncher already running"
    fi
else
    log "no DISPLAY; xcape and ulauncher will start on next login"
fi

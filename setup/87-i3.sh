#!/usr/bin/env bash
# 87-i3.sh - i3 as an opt-in XFCE-flavored session (Phase 2).
#
# Installs i3 + i3status, drops a new xsession at /usr/share/xsessions/
# xfce-i3.desktop, and a launcher at /usr/local/bin/start-xfce-i3. Pick
# "Xfce with i3" from the LightDM gear menu at login to use it; the
# default "Xfce Session" stays untouched.
#
# Why a separate session instead of swapping mid-session via --replace:
# multi-monitor + an XFCE session that expects xfwm4 don't survive a
# live WM swap cleanly (windows scatter across i3 workspaces, panel
# work-area goes wrong, decorations don't come back). A fresh login is
# the only reliable path. Logging out + re-picking from LightDM is the
# round-trip cost; ~5 seconds. Stateful apps (Vivaldi tabs, VS Code
# buffers) preserve themselves; terminals don't.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

# 1. Install i3 + i3status, plus dex (replays XDG autostart entries in
#    the i3 session, since there's no xfce4-session to do it).
$SUDO apt-get install -y i3 i3status dex

# 2. /usr/local/bin/start-xfce-i3: launches XFCE background bits, then
#    execs i3 as the session's main process. When i3 exits, the X
#    session ends and LightDM comes back. No xfce4-session involved,
#    so there is no session save/restore for this session profile.
WRAPPER=/usr/local/bin/start-xfce-i3
WRAPPER_BODY=$(cat <<'EOF'
#!/usr/bin/env bash
# start-xfce-i3 - XFCE components + i3 as the session's main loop.
# Each login is a known clean state; no session save/restore.

set -eu

# xfsettingsd first -- theme, GTK config, cursor, keyboard repeat. Apps
# started afterwards inherit it. It's also an XDG autostart entry, so the
# dex pass below touches it again; xfsettingsd is single-instance, so the
# second start is a harmless no-op. We start it explicitly only to make
# sure it's up before the panel and everything else.
xfsettingsd >/dev/null 2>&1 &
sleep 0.3

# The panel is a core xfce4-session component, NOT an XDG autostart
# entry, so dex won't cover it. Launch it directly.
xfce4-panel >/dev/null 2>&1 &

# dex replays the full XDG autostart set exactly as xfce4-session would,
# filtered to the XFCE environment. On this machine that resolves to:
# gnome-keyring (ssh-agent + secret store), the polkit-mate auth agent,
# light-locker (screen lock), xfce4-notifyd (notifications), clipman,
# blueman, nm-applet, ulauncher, xcape (tap-Super launcher) and the
# power manager. Hand-listing these is how we missed xcape the first
# time; dex keeps the set self-maintaining as autostart entries change.
dex --autostart --environment XFCE >/dev/null 2>&1 &

# i3 becomes the session's foreground process. When it exits, the
# session ends.
exec i3
EOF
)

if [[ ! -f "$WRAPPER" ]] || ! diff -q <(printf '%s\n' "$WRAPPER_BODY") "$WRAPPER" >/dev/null 2>&1; then
    log "writing $WRAPPER"
    printf '%s\n' "$WRAPPER_BODY" | $SUDO tee "$WRAPPER" >/dev/null
    $SUDO chmod +x "$WRAPPER"
else
    log "$WRAPPER already in place"
fi

# 3. /usr/share/xsessions/xfce-i3.desktop: appears in the LightDM gear
#    menu as "Xfce with i3". DesktopNames=XFCE so apps that branch on
#    the desktop env (autostart entries, themes) treat us as XFCE.
SESSION_FILE=/usr/share/xsessions/xfce-i3.desktop
SESSION_BODY=$(cat <<EOF
[Desktop Entry]
Name=Xfce with i3
Comment=XFCE-style session with i3 as the window manager
Exec=$WRAPPER
Icon=i3
Type=Application
DesktopNames=XFCE
EOF
)

if [[ ! -f "$SESSION_FILE" ]] || ! diff -q <(printf '%s\n' "$SESSION_BODY") "$SESSION_FILE" >/dev/null 2>&1; then
    log "writing $SESSION_FILE"
    printf '%s\n' "$SESSION_BODY" | $SUDO tee "$SESSION_FILE" >/dev/null
else
    log "$SESSION_FILE already in place"
fi

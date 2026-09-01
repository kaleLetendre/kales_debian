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
#    the i3 session, since there's no xfce4-session to do it). nm-tray
#    replaces nm-applet for the network icon: Debian's nm-applet still
#    only docks as legacy XEMBED, and xfce4-panel 4.20's tray plugin
#    silently won't claim _NET_SYSTEM_TRAY_S0, so the icon never shows.
#    nm-tray speaks StatusNotifierItem natively, which the panel does
#    handle. The nm-applet autostart entry is suppressed by a per-user
#    override stowed via dotfiles/autostart/.
$SUDO apt-get install -y i3 i3status dex nm-tray

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

# Wait for the panel's "Status Tray" plugin to own the StatusNotifier
# bus name before dex launches nm-applet / blueman-applet. Without
# this gate, on a slow boot the applets register against a missing
# watcher, give up, and the tray icons silently never appear -- the
# only signal that anything went wrong is "my tray is empty after
# reboot". The panel normally has the name in <300ms; 10s is the
# absolute ceiling. Output is swallowed (script runs under LightDM,
# no tty); the loop's exit condition is the only success signal.
for _ in $(seq 1 100); do
    gdbus call --session \
        --dest org.freedesktop.DBus \
        --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.NameHasOwner \
        org.kde.StatusNotifierWatcher 2>/dev/null \
        | grep -q true && break
    sleep 0.1
done

# dex replays the full XDG autostart set exactly as xfce4-session would,
# filtered to the XFCE environment. On this machine that resolves to:
# gnome-keyring (ssh-agent + secret store), the polkit-mate auth agent,
# light-locker (screen lock), xfce4-notifyd (notifications), clipman,
# blueman, nm-tray, ulauncher, xcape (tap-Super launcher) and the power
# manager. nm-applet's autostart is suppressed by a per-user Hidden=true
# override (dotfiles/autostart). Hand-listing these is how we missed
# xcape the first time; dex keeps the set self-maintaining as autostart
# entries change.
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

# 4. Drop the xfce4-panel "Action Buttons" plugin (plugin type "actions").
# A pure-i3 session doesn't run xfce4-session, so every item in that
# plugin (Log Out / Shut Down / Suspend / Restart) stays greyed -- the
# plugin gates on org.xfce.SessionManager which we deliberately don't
# provide. logind allows the underlying actions; the i3 keybinds in
# dotfiles/i3/.config/i3/config (Super+Shift+P/B/S/E) replace it.
# This is per-user xfconf -- runs unprivileged, applies to both the
# "Xfce with i3" and stock "Xfce Session" panels (one panel config per
# user).
#
# Idempotent: only acts when the plugin is still present in the panel-1
# plugin-ids array. Looks up the plugin id by type ("actions") so this
# works across machines where the integer id may differ.
if command -v xfconf-query >/dev/null 2>&1; then
    PANEL_PROP=/panels/panel-1/plugin-ids
    # Find the integer id whose plugin type is "actions". xfconf-query
    # output for /plugins is two-column: "/plugins/plugin-N  <type>".
    actions_id=$(xfconf-query -c xfce4-panel -lv 2>/dev/null \
        | awk '$1 ~ /^\/plugins\/plugin-[0-9]+$/ && $2 == "actions" { sub("/plugins/plugin-", "", $1); print $1; exit }')
    if [[ -n "$actions_id" ]] && \
       xfconf-query -c xfce4-panel -p "$PANEL_PROP" 2>/dev/null | grep -qx "$actions_id"; then
        log "removing xfce panel Action Buttons (plugin-$actions_id) from panel-1"
        # Read current ids, drop the target, rewrite. Build the
        # --type/--set arg pairs that xfconf-query needs for arrays.
        keep_ids=$(xfconf-query -c xfce4-panel -p "$PANEL_PROP" \
            | awk -v drop="$actions_id" '/^[0-9]+$/ && $1 != drop { print }')
        args=()
        for id in $keep_ids; do
            args+=(--type int --set "$id")
        done
        # --force-array keeps it an array even if only one item remained.
        xfconf-query -c xfce4-panel -p "$PANEL_PROP" --force-array "${args[@]}"
        # Clear the now-orphaned plugin definition.
        xfconf-query -c xfce4-panel -rR -p "/plugins/plugin-$actions_id"
        # Live-reload the panel if it's running so the change is visible
        # without re-login. SIGUSR1 = re-read config. Tolerate the panel
        # not running (e.g. bootstrap from a TTY before any X session).
        pkill -USR1 xfce4-panel 2>/dev/null || true
    else
        log "xfce panel: Action Buttons already absent"
    fi
fi

# 5. Point XFCE's lock plumbing at our i3lock script.
#
# Symptom this fixes: an occasional popup after closing/opening the lid --
# "None of the screen lock tools ran successfully, the screen will not be
# locked." It comes from xfce4-power-manager (string lives in libxfce4ui),
# which locks before suspend by default (lock-screen-suspend-hibernate
# defaults to TRUE) and on the lid trigger.
#
# Why it fails in this session: libxfce4ui's xfce_screensaver_lock() only
# knows how to lock via a D-Bus screensaver owner (org.{freedesktop,xfce,
# gnome,mate,cinnamon}.ScreenSaver) or by spawning xfce4-screensaver /
# light-locker-command / xscreensaver-command / xdg-screensaver. None apply
# here: xfce4-screensaver and xscreensaver aren't installed, light-locker is
# deliberately suppressed (dotfiles/autostart Hidden=true, we lock with
# i3lock), and no D-Bus name is claimed. Every candidate fails -> popup, and
# the machine suspends UNLOCKED.
#
# The escape hatch: libxfce4ui tries the xfce4-session channel's
# /general/LockCommand FIRST, and honors it even though xfce4-session itself
# isn't running in this session (verified: lock() returns TRUE and runs the
# command). So hand it lock.sh -- the same i3lock-color invocation Ctrl+Alt+L
# uses -- and the whole XFCE lock path starts working instead of erroring.
#
# Absolute path, not ~: the value is spawned as a bare command line, so no
# shell and no tilde expansion. Property is per-user, so $HOME is correct.
#
# Note this does NOT fix xflock4, which in Xfce 4.20 is only a D-Bus Lock
# call to org.xfce.SessionManager and no-ops with no xfce4-session. Nothing
# here calls xflock4; see the comment in dotfiles/i3/.config/i3/config.
#
# Idempotent: skips the write when the property already holds this value.
if command -v xfconf-query >/dev/null 2>&1; then
    LOCK_CMD="$HOME/.config/i3/lock.sh"
    current=$(xfconf-query -c xfce4-session -p /general/LockCommand 2>/dev/null || true)
    if [[ "$current" == "$LOCK_CMD" ]]; then
        log "xfce4-session LockCommand already set to lock.sh"
    else
        log "setting xfce4-session /general/LockCommand -> $LOCK_CMD"
        # --create makes this work on a fresh machine where xfce4-session's
        # xfconf channel has never been written (property doesn't exist yet).
        xfconf-query -c xfce4-session -p /general/LockCommand \
            --create --type string --set "$LOCK_CMD"
        # Pick it up without a re-login if the power manager is running.
        # Tolerate it being absent (bootstrap from a TTY, no X session yet).
        xfce4-power-manager --restart 2>/dev/null || true
    fi
fi

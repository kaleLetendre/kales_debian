#!/usr/bin/env bash
# 41-sddm.sh - replace LightDM with SDDM + the Qt6-native "astronaut" fancy
# login theme. Idempotent.
#
# Why SDDM: a themeable QML greeter (animated backgrounds, blur) vs LightDM's
# flat GTK greeter. Debian 13 ships sddm 0.21 built against Qt6, so the classic
# Qt5 themes (e.g. Sugar Candy, which needs QtGraphicalEffects) would render
# blank. We use Keyitdev/sddm-astronaut-theme, written for Qt6; it needs the
# qt6 svg / effects / multimedia QML modules installed below.
#
# Session picker preserved: SDDM reads the same /usr/share/xsessions/*.desktop
# as LightDM, so the "Xfce with i3" session from 87-i3.sh still shows in the
# SDDM session dropdown -- the i3 opt-in is unaffected.
#
# ROLLBACK (if a boot lands on a broken login): switch to a text console with
# Ctrl+Alt+F3, log in, then:
#     sudo systemctl disable sddm && sudo systemctl enable lightdm && sudo reboot
# LightDM is never removed, so this always gets you back.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

THEME_DIR=/usr/share/sddm/themes/sddm-astronaut-theme
THEME_REPO="https://github.com/Keyitdev/sddm-astronaut-theme.git"
# Sub-theme: one of Themes/*.conf in the repo (astronaut, black_hole,
# cyberpunk, japanese_aesthetic, pixel_sakura, purple_leaves, ...). Change
# this and re-run to restyle the login screen.
SUBTHEME="purple_leaves"

# 1. SDDM + the Qt6 QML modules the astronaut theme needs (all confirmed
#    present in Debian 13). svg/effects drive the visuals; multimedia +
#    virtualkeyboard back the video/animated backgrounds and on-screen keyboard
#    some sub-themes use; qt5compat-graphicaleffects covers older effect calls.
log "installing sddm + Qt6 theme deps"
$SUDO apt-get install -y \
    sddm \
    libqt6svg6 libqt6multimedia6 libxcb-cursor0 \
    qml6-module-qtquick-controls qml6-module-qtquick-effects \
    qml6-module-qtmultimedia qml6-module-qt5compat-graphicaleffects \
    qt6-virtualkeyboard-plugin

# 2. Theme: clone (or fast-forward) into the sddm themes dir, then install its
#    bundled fonts so the clock/labels render as designed.
if [[ ! -d "$THEME_DIR/.git" ]]; then
    log "cloning astronaut theme -> $THEME_DIR"
    $SUDO git clone -b master --depth 1 "$THEME_REPO" "$THEME_DIR"
else
    log "updating astronaut theme"
    $SUDO git -C "$THEME_DIR" pull --ff-only
fi
# -n so re-runs don't re-copy; the theme ships loose fonts plus an OpenSans dir.
$SUDO cp -rn "$THEME_DIR"/Fonts/* /usr/share/fonts/
$SUDO fc-cache -f >/dev/null

# 3. Select the sub-theme by rewriting the ConfigFile line in metadata.desktop
#    (the theme reads its active variant from there). Idempotent.
$SUDO sed -i "s|^ConfigFile=.*|ConfigFile=Themes/${SUBTHEME}.conf|" \
    "$THEME_DIR/metadata.desktop"

# 4. Point SDDM at the theme via a conf.d drop-in (leaves any packaged
#    /etc/sddm.conf alone; conf.d takes precedence and is trivial to remove).
$SUDO install -d /etc/sddm.conf.d
printf '[Theme]\nCurrent=sddm-astronaut-theme\n' \
    | $SUDO tee /etc/sddm.conf.d/theme.conf >/dev/null

# 5. Make SDDM the boot display manager instead of LightDM. The systemd
#    display-manager.service alias is what actually decides at boot; flip it,
#    and mirror the choice into /etc/X11 for tools that read that file. LightDM
#    stays installed for rollback. This does NOT stop the running LightDM --
#    it only changes what starts on the next boot. Idempotent.
current_dm=$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)
if [[ "$current_dm" != *sddm.service ]]; then
    log "switching default display manager: lightdm -> sddm (takes effect next boot)"
    $SUDO systemctl disable lightdm.service
    $SUDO systemctl enable sddm.service
    echo /usr/bin/sddm | $SUDO tee /etc/X11/default-display-manager >/dev/null
else
    log "sddm is already the default display manager"
fi

# Point the user at a no-reboot preview + the rollback, using the greeter
# binary this sddm actually shipped (name varies: sddm-greeter / -qt6).
greeter=$(dpkg -L sddm 2>/dev/null | grep -E '/sddm-greeter(-qt6)?$' | head -1 || true)
echo
log "SDDM configured with the '${SUBTHEME}' theme."
log "PREVIEW without rebooting (renders in a window):"
log "    ${greeter:-sddm-greeter} --test-mode --theme $THEME_DIR"
log "Then reboot to use it for real. If login is broken: Ctrl+Alt+F3, log in,"
log "    sudo systemctl disable sddm && sudo systemctl enable lightdm && sudo reboot"

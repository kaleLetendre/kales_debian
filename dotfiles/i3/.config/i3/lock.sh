#!/usr/bin/env bash
# lock.sh - the screen-lock command, stowed to ~/.config/i3/lock.sh.
#
# Bound to Ctrl+Alt+L. In the i3 session xfsettingsd owns that grab and runs
# this via `bash -c "$HOME/.config/i3/lock.sh"` (see setup/76-app-hotkeys.sh);
# the i3 config has a mirror bindsym too. Keeping the invocation in a script
# (not a giant xfconf string) makes the flags readable and easy to tweak.
#
# Prefers i3lock-color (built from source by setup/99-i3lock-color.sh) for a
# blurred background + clock + state-colored ring. Falls back to Debian's
# vanilla i3lock when the fork isn't installed yet, so the lock keybind always
# works -- even between adding this file and running the build module.

set -eu

if command -v i3lock-color >/dev/null 2>&1; then
    # Colors are RRGGBBAA (8 hex digits). States: normal / ver(ifying) /
    # wrong. Tweak freely -- this is the whole customization surface.
    exec i3lock-color \
        --blur 6 \
        --clock --indicator \
        --time-str "%H:%M" --time-size 48 --time-color ffffffff \
        --date-str "%A %d %B" --date-size 20 --date-color ffffffcc \
        --radius 110 --ring-width 8 \
        --inside-color 00000099 --ring-color ffffffdd \
        --insidever-color 00000099 --ringver-color 5fafafff \
        --insidewrong-color 00000099 --ringwrong-color cc4444ff \
        --line-uses-inside \
        --keyhl-color 5fafafff --bshl-color cc4444ff \
        --separator-color 00000000 \
        --verif-text "checking..." --wrong-text "try again" --noinput-text ""
else
    # Vanilla i3lock: black screen, show failed-attempt count.
    exec i3lock -c 000000 -f
fi

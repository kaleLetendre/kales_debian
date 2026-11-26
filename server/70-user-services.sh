#!/usr/bin/env bash
# server/70-user-services.sh - the server's systemd *user* services, and the
# helper script they run. Idempotent.
#
# Unit files come from two places:
#   1. server/stow/ (this repo) -- stowed into $HOME, server-only. A separate
#      stow dir instead of dotfiles/ because bootstrap stows every dotfiles/
#      package on every machine, and none of this belongs on the laptop.
#        claude-rc-sync.{path,service}  - keeps one claude-remote-control@
#                                         instance per project in ~/personal
#        claude-remote-control@.service - Claude Code Remote Control server
#                                         for one directory (%f)
#        pcscale-watchdog.{service,timer} - every 10 min, terminate RunPod
#                                         pods past their ceiling or idle
#        discord-ollama-bot2.service    - second bot instance (.env2)
#        ~/.local/bin/claude-rc-sync    - the reconcile script
#   2. Project repos that ship their own unit (they stay the source of
#      truth; we symlink to them). Skipped if the project isn't cloned.
#
# --no-folding: without it, stow on a fresh machine would symlink the whole
# ~/.config/systemd/user directory into the repo, and `systemctl enable`
# would then write its *.wants/ symlinks inside the git tree.
#
# Lingering keeps user services running with nobody logged in (and starts
# them at boot), which is the whole point on a headless server.
#
# Enabled state mirrors the live server: the Discord bots are installed but
# left disabled (start them by hand); everything else is enabled.

set -euo pipefail

SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STOW_DIR="$REPO_DIR/server/stow"
UNIT_DIR="$HOME/.config/systemd/user"
BACKUP_DIR="$UNIT_DIR/.pre-kales-backup"
P="$HOME/personal"

# project unit file -> where it is installed
declare -A PROJECT_UNITS=(
    ["$P/discord-ollama-bot/discord-ollama-bot.service"]=discord-ollama-bot.service
    ["$P/research-workbench/workbench/research-workbench.service"]=research-workbench.service
    ["$P/continual-pc/steps/06_continual_pc/pc-monitor.service"]=pc-monitor.service
)

# A hand-copied regular file where a symlink should go would make stow / ln
# refuse (or silently keep the stale copy). Move it aside, once.
backup_if_regular() {
    local target="$1"
    if [[ -f "$target" && ! -L "$target" ]]; then
        mkdir -p "$BACKUP_DIR"
        log "moving hand-installed $(basename "$target") to $BACKUP_DIR"
        mv "$target" "$BACKUP_DIR/"
    fi
}

if ! loginctl show-user "$USER" -p Linger | grep -q '=yes'; then
    log "enabling lingering for $USER"
    $SUDO loginctl enable-linger "$USER"
fi

mkdir -p "$UNIT_DIR" "$HOME/.local/bin"

for f in "$STOW_DIR"/systemd-user/.config/systemd/user/*; do
    backup_if_regular "$UNIT_DIR/$(basename "$f")"
done
backup_if_regular "$HOME/.local/bin/claude-rc-sync"

log "stowing server units + bin"
stow --no-folding -d "$STOW_DIR" -t "$HOME" -R systemd-user bin

for src in "${!PROJECT_UNITS[@]}"; do
    name="${PROJECT_UNITS[$src]}"
    if [[ -f "$src" ]]; then
        backup_if_regular "$UNIT_DIR/$name"
        ln -sfn "$src" "$UNIT_DIR/$name"
    else
        log "skip $name: $src not present (clone the project first)"
    fi
done

systemctl --user daemon-reload

# Enable + start; each is a no-op when already enabled/running.
enable_if_present() {
    local unit="$1" needs="$2"
    if [[ -e "$needs" ]]; then
        systemctl --user enable --now "$unit"
    else
        log "not enabling $unit: $needs missing"
    fi
}

enable_if_present claude-rc-sync.path     "$P"
enable_if_present pcscale-watchdog.timer  "$P/continual-pc"
enable_if_present pc-monitor.service      "$UNIT_DIR/pc-monitor.service"
enable_if_present research-workbench.service "$UNIT_DIR/research-workbench.service"

# Run one reconcile now so every project gets its Remote Control instance
# without waiting for ~/personal to change.
if [[ -d "$P" ]]; then
    systemctl --user start claude-rc-sync.service
fi

#!/usr/bin/env bash
# 20-base-packages.sh - CLI tools expected on every machine. Idempotent.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

log "apt update"
$SUDO apt-get update

log "base packages"
# jq parses JSON on the command line -- the Claude Code status line
# (dotfiles/claude/.claude/statusline.sh) pipes its input through it.
# python3 ships by default on Debian, but `venv` and `pip` are split into
# separate packages -- without them, `python3 -m venv` produces a broken
# venv with no pip inside. Both are needed for any project that bootstraps
# itself into a venv (e.g. ./install.sh scripts that pip install -r ...).
#
# kitty-terminfo provides the `xterm-kitty` terminfo entry. The local
# terminal is kitty, which sets TERM=xterm-kitty; SSHing into a box that
# lacks this entry breaks everything that reads terminfo (clear, tput,
# vim, less) with `'xterm-kitty': unknown terminal type`. It's a tiny
# data-only package (no kitty binary), so it's safe on servers too.
#
# ethtool inspects/sets NIC state -- link speed & duplex, carrier, and
# hardware offloads. It's the first thing you reach for when Ethernet
# "gets nothing": it distinguishes a dead link from a live link that
# isn't passing traffic (e.g. DHCP failing while the port is up).
$SUDO apt-get install -y \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    stow \
    jq \
    htop \
    tmux \
    build-essential \
    postgresql-client \
    python3-venv \
    python3-pip \
    ethtool \
    kitty-terminfo

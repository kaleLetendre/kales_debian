#!/usr/bin/env bash
# bootstrap.sh - one-command setup for a fresh Debian 13 XFCE install.
# Idempotent: safe to re-run any time.
#
# Layout:
#   setup/NN-thing.sh   - one concern per file, run in lex order on every
#                         machine. Add a new file to add a new concern.
#   hardware/<name>.sh  - runs only when the DMI product name matches.
#   server/NN-thing.sh  - extra layer, runs in lex order only on a `server`
#                         (chosen by the role menu below). A server is just
#                         a client plus this layer.
#   dotfiles/<pkg>/...  - stow packages, symlinked into $HOME at the end.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

log() { printf "\n== %s ==\n" "$*"; }

log "bootstrap starting"
echo "Repo: $REPO_DIR"
echo "Host: $(hostname)"

# Role: is this machine a `client` (the full desktop setup, like the laptop)
# or a `server` (all of that, plus the server/ layer that makes it reachable
# over Tailscale)? Both run every setup/ module identically; the only
# difference is whether server/ runs at the end.
#
# The choice is remembered in a gitignored .role file so re-runs don't
# reprompt. Override with `ROLE=server ./bootstrap.sh`, or delete .role.
ROLE_FILE="$REPO_DIR/.role"
ROLE="${ROLE:-}"
if [[ -z "$ROLE" && -f "$ROLE_FILE" ]]; then
    ROLE="$(cat "$ROLE_FILE")"
fi
if [[ -z "$ROLE" ]]; then
    # Smart default from the hostname: a box named like a server defaults to
    # server, everything else to client. Press Enter to accept the default.
    default="client"
    case "$(hostname)" in
        *server*) default="server" ;;
    esac
    echo
    echo "Which role is this machine?"
    echo "  1) client - full desktop setup (this laptop)"
    echo "  2) server - all of that, plus the server/ layer (reachable over Tailscale SSH)"
    read -r -p "Role [1=client, 2=server] (default: $default): " pick
    case "$pick" in
        1) ROLE="client" ;;
        2) ROLE="server" ;;
        *) ROLE="$default" ;;
    esac
fi
if [[ "$ROLE" != "client" && "$ROLE" != "server" ]]; then
    echo "Unknown role '$ROLE'; falling back to client." >&2
    ROLE="client"
fi
printf '%s\n' "$ROLE" > "$ROLE_FILE"
# Mirror the role to a stable path in $HOME so runtime consumers that don't
# know where the repo lives (e.g. the zsh prompt) can read it. ROLE_FILE is
# repo-relative and gitignored; this marker is the runtime-facing copy.
mkdir -p "$HOME/.config/kales"
printf '%s\n' "$ROLE" > "$HOME/.config/kales/role"
log "role: $ROLE"

# Setup modules. Numbered prefix controls order. Each must be idempotent.
if [[ -d "$REPO_DIR/setup" ]]; then
    shopt -s nullglob
    for module in "$REPO_DIR/setup"/*.sh; do
        log "$(basename "$module")"
        bash "$module"
    done
    shopt -u nullglob
fi

# Hardware-specific layer, picked by DMI product name.
# /sys/class/dmi/id/product_name is readable without root and needs no extra package.
PRODUCT="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
MACHINE=""
case "$PRODUCT" in
    *"Precision 3591"*) MACHINE="precision-3591" ;;
esac

if [[ -n "$MACHINE" && -f "$REPO_DIR/hardware/$MACHINE.sh" ]]; then
    log "hardware: $MACHINE"
    bash "$REPO_DIR/hardware/$MACHINE.sh"
else
    log "hardware: no specific profile (product='$PRODUCT')"
fi

# Dotfiles via stow. Each subdir of dotfiles/ is a stow package.
if command -v stow >/dev/null 2>&1 && [[ -d "$REPO_DIR/dotfiles" ]]; then
    shopt -s nullglob
    pkgs=("$REPO_DIR/dotfiles"/*/)
    if (( ${#pkgs[@]} > 0 )); then
        log "dotfiles: stowing"
        cd "$REPO_DIR/dotfiles"
        for p in */; do
            stow -t "$HOME" -R "${p%/}"
        done
    fi
fi

# Server layer. Only on a `server`: the full client setup above has already
# run, so this just adds what makes the box a server. Numbered modules in
# server/ run in lex order, like setup/. Each must be idempotent.
if [[ "$ROLE" == "server" && -d "$REPO_DIR/server" ]]; then
    cd "$REPO_DIR"
    shopt -s nullglob
    for module in "$REPO_DIR/server"/*.sh; do
        log "server: $(basename "$module")"
        bash "$module"
    done
    shopt -u nullglob
fi

log "bootstrap done"
echo
echo "Reboot recommended: some changes (e.g. xfce4-terminal settings,"
echo "group memberships, kernel/driver updates) only take effect after a"
echo "fresh login or full restart."
echo
read -r -p "Reboot now? [y/N] " ans
if [[ "${ans,,}" == y* ]]; then
    sudo systemctl reboot
fi

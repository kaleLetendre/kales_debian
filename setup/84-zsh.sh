#!/usr/bin/env bash
# 84-zsh.sh - zsh as the interactive login shell, plus fzf (the fuzzy
# engine the zsh widgets build on). Idempotent.
#
# Only the interactive login shell changes; scripts stay bash
# (#!/usr/bin/env bash). The zsh config itself is a stow package
# (dotfiles/zsh) applied at the end of bootstrap, grown one file at a
# time under ~/.zshrc.d/.
#
# Note: chsh takes effect on the NEXT login, not the running session.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

# 1. Install zsh + fzf + zoxide.
#    - fzf is the fuzzy engine the zsh widgets build on. We use only the
#      binary and write our own line-editor widgets rather than sourcing
#      fzf's bundled key bindings.
#    - zoxide tracks every cd and lets `z <fragment>` jump to a previously
#      visited directory. Wired up in dotfiles/zsh/.zshrc.d/20-zoxide.zsh.
log "installing zsh, fzf, zoxide"
$SUDO apt-get update
$SUDO apt-get install -y zsh fzf zoxide

# 2. Make zsh the login shell for this user. apt's zsh postinst registers
#    /usr/bin/zsh in /etc/shells, which chsh requires. Running chsh under
#    sudo avoids the interactive password prompt.
zsh_path="$(command -v zsh)"
user="$(id -un)"
current_shell="$(getent passwd "$user" | cut -d: -f7)"
if [[ "$current_shell" != "$zsh_path" ]]; then
    log "setting login shell to $zsh_path (effective next login)"
    $SUDO chsh -s "$zsh_path" "$user"
else
    log "login shell already $zsh_path"
fi

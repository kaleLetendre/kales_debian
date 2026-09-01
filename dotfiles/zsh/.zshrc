# .zshrc - interactive zsh config. Hand-built, grown brick by brick.
# This file is interactive-only; scripts stay bash (#!/usr/bin/env bash).
# Tracked in kales_debian and stowed into $HOME.

# --- History ---
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY         # one shared history across running sessions
setopt HIST_IGNORE_ALL_DUPS  # drop older duplicates of a command
setopt HIST_IGNORE_SPACE     # a leading space keeps a command out of history

# --- Completion ---
autoload -Uz compinit && compinit    # enable the completion system
zstyle ':completion:*' menu select   # arrow-key menu to pick a completion

# --- Quality of life ---
setopt AUTO_CD               # type a directory name to cd into it

# Turn off terminal flow control. By default the tty driver eats ctrl+s as
# XOFF (freeze the screen) and ctrl+q as XON, so neither key ever reaches
# the program running in the terminal. nvim wants both: ctrl+s to save and
# ctrl+q for blockwise visual, per dotfiles/nvim/.../config/standard-keys.lua.
# Nothing here relies on software flow control, and a frozen terminal after
# a stray ctrl+s is a worse default than not having it.
# Guarded on stdin being a terminal: an interactive zsh without a tty
# (zsh -i -c '...' in a pipeline, say) has nothing for stty to configure and
# would print "Inappropriate ioctl for device" on every invocation.
[[ -t 0 ]] && stty -ixon

# --- Bricks ---
# Each feature is its own file under ~/.zshrc.d/, sourced in lexical order.
# Add a feature by dropping a new NN-name.zsh there (tracked in the repo).
if [[ -d "$HOME/.zshrc.d" ]]; then
    for _f in "$HOME"/.zshrc.d/*.zsh(N); do
        source "$_f"
    done
    unset _f
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


# Added by Antigravity CLI installer
export PATH="/home/kl/.local/bin:$PATH"

# --- Secrets ---
# API keys and tokens live outside git -- secrets/ is in .gitignore -- so this
# file exists on the machines that need it and simply is absent on the others.
# The guard is deliberate: a missing secrets file must not break the shell.
#
# ${(%):-%N} is the path of the file currently being sourced (this .zshrc).
# :A resolves it through the stow symlink back into the repo, and the three
# :h strip .zshrc -> zsh -> dotfiles, landing on the repo root. So this keeps
# working wherever the repo is cloned, rather than hardcoding ~/kales_debian.
KALES_SECRETS="${${(%):-%N}:A:h:h:h}/secrets/env.zsh"
[[ -f "$KALES_SECRETS" ]] && source "$KALES_SECRETS"

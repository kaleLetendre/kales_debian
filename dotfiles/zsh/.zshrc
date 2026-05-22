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

# --- Bricks ---
# Each feature is its own file under ~/.zshrc.d/, sourced in lexical order.
# Add a feature by dropping a new NN-name.zsh there (tracked in the repo).
if [[ -d "$HOME/.zshrc.d" ]]; then
    for _f in "$HOME"/.zshrc.d/*.zsh(N); do
        source "$_f"
    done
    unset _f
fi

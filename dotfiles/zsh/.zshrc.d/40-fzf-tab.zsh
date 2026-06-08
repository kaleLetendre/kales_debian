# 40-fzf-tab.zsh - replace zsh's completion menu with an fzf popup.
#
# After Tab, instead of zsh's stock arrow-key menu, you get a fuzzy-
# filterable fzf list of the same completions (flags, subcommands, files,
# branches, etc.) -- with descriptions inline where the completion
# function provides them. Discovery without a new verb to remember.
#
# Quality depends on the underlying zsh completion script per command:
# excellent for git/docker/kubectl/systemctl/ssh; bare filenames for
# random CLIs unless _gnu_generic is added as a fallback completer later.
#
# Plugin source is the hand-clone from setup/84-zsh.sh. Sourced after
# compinit (the .zshrc runs compinit before this dir is sourced).
#
# fzf-tab is incompatible with `zstyle ':completion:*' menu select`
# (which the .zshrc enables by default), so we drop that style here.
# Deleting this brick restores the default menu-select behavior.

_fzf_tab_plugin="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/fzf-tab/fzf-tab.plugin.zsh"
if [[ -r "$_fzf_tab_plugin" ]]; then
    zstyle -d ':completion:*' menu
    source "$_fzf_tab_plugin"
fi
unset _fzf_tab_plugin

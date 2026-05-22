# 10-fzf-file.zsh - Ctrl+T: fuzzy-pick a file from the current directory
# and insert it onto the command line at the cursor. Runs nothing.
#
# Built on fzf (the fuzzy engine). The glue is a ZLE widget: a function
# registered with `zle -N` and bound to a key. Inside a widget, LBUFFER
# is the text left of the cursor and RBUFFER the text right of it, so
# appending to LBUFFER inserts at the cursor and leaves the cursor after.

# Only wire this up if fzf is actually installed.
if (( $+commands[fzf] )); then
    fuzzy-file-insert() {
        local selection
        # ls -1A: one entry per line, include dotfiles, skip . and ..
        # fzf does the fuzzy filtering. Esc/Ctrl-C makes fzf exit
        # non-zero, so `|| return` leaves the current line untouched.
        selection="$(ls -1A | fzf --height=40% --reverse --prompt='file> ')" || return
        # ${(q)...} shell-quotes the pick so spaces/specials survive.
        LBUFFER+="${(q)selection} "
        # Redraw prompt + line after fzf's inline UI closes.
        zle reset-prompt
    }
    zle -N fuzzy-file-insert
    # Ctrl+T is the conventional "insert a file here" key (default zsh
    # binds it to transpose-chars, which is rarely used).
    bindkey '^T' fuzzy-file-insert
fi

# 20-zoxide.zsh - `z <fragment>` jumps to a previously-visited directory.
#
# zoxide hooks into chpwd to log every cd into its database, scored by
# "frecency" (frequency + recency). `z kales` jumps to ~/kales_debian
# once you've been there a few times. plain cd is untouched.
#
# Bonus verb: `zi` opens an fzf picker over the database for ambiguous
# fragments. Not memorized, just there when you want it.

if (( $+commands[zoxide] )); then
    eval "$(zoxide init zsh)"
fi

# 50-keybindings.zsh - ZLE bindings for keys that zsh's default emacs
# keymap doesn't recognize.
#
# When ZLE sees an unbound key sequence it falls through to self-insert,
# so Ctrl+Right ends up inserting the literal "^[[1;5C" into the buffer.
# Bash hides this because readline reads /etc/inputrc; zsh's ZLE doesn't.
#
# Sequences below are xterm-style, which xfce4-terminal (VTE) follows.
# To discover what a key actually sends, type `cat -v` and press it, or
# at the zsh prompt hit Ctrl+V then the key -- the raw sequence prints
# inline.

# Word-wise cursor movement
bindkey "^[[1;5C" forward-word        # Ctrl+Right
bindkey "^[[1;5D" backward-word       # Ctrl+Left

# Word-wise deletion
# VTE sends ^H (0x08) for Ctrl+Backspace; bare Backspace is ^? (0x7f),
# which stays bound to backward-delete-char as usual.
bindkey "^H"      backward-kill-word  # Ctrl+Backspace
bindkey "^[[3;5~" kill-word           # Ctrl+Delete

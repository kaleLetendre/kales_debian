# 35-title.zsh - terminal/window title = current directory.
#
# Sends OSC 2 ("set window title") with %~ (cwd, with $HOME shown as ~)
# so the i3 workspace bar and any taskbar/window list shows the folder
# the terminal is in, not whatever tool happens to be running. Matches
# the prompt format from 30-prompt.zsh on purpose.
#
# Fired from both precmd (before each prompt is drawn) and preexec
# (just before a command runs). The preexec hook is what keeps the
# title pinned to the cwd while a foreground program is up -- without
# it, the title would only refresh when control returned to zsh.
#
# Inferior programs that explicitly write OSC 2 themselves will still
# win for as long as they run (vim with `set title`, ssh remotes, etc.).
# Claude Code is the common offender on this machine; it's neutered via
# CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 in dotfiles/claude/.claude/
# settings.json so its title spam can't outrun this hook.
#
# Guarded on $TERM so we don't print escape sequences into a dumb tty
# (e.g. a TTY console login) where they'd show up as literal junk.

case "$TERM" in
    xterm*|screen*|tmux*|rxvt*|alacritty|kitty)
        _set_term_title() { print -Pn '\e]2;%~\a' }
        precmd_functions+=(_set_term_title)
        preexec_functions+=(_set_term_title)
        ;;
esac

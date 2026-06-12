# 30-prompt.zsh - prompt format: HH:MM|~/path:
#
# zsh prompt-expansion tokens used (no PROMPT_SUBST needed, these are
# native to the prompt syntax):
#
#   %D{%H:%M}  current time as zero-padded 24-hour HH:MM. Re-evaluated
#              every time the prompt is drawn, so the time updates after
#              every command (not live between commands -- for that you'd
#              need a TMOUT + TRAPALRM that calls `zle reset-prompt`).
#   %~         current working directory, $HOME shown as ~. Sister tokens
#              if I ever want to switch:
#                %d   - raw absolute path (/home/kl/kales_debian)
#                %1~  - last segment only (kales_debian)
#
#   %F{blue}..%f  set foreground colour to blue, then reset. Native prompt
#                 colour tokens, no PROMPT_SUBST needed.
#
# Trailing space after the colon so typed commands don't touch it.
#
# On a server (role marker written by bootstrap.sh) prepend a blue `S` so an
# SSH session into the box is unmistakable at a glance. Clients get the plain
# prompt. The marker lives at ~/.config/kales/role; absent == client.

if [[ -r "$HOME/.config/kales/role" && "$(<"$HOME/.config/kales/role")" == server ]]; then
    PROMPT='%F{blue}S%f %D{%H:%M}|%~: '
else
    PROMPT='%D{%H:%M}|%~: '
fi

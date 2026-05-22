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
# Trailing space after the colon so typed commands don't touch it.

PROMPT='%D{%H:%M}|%~: '

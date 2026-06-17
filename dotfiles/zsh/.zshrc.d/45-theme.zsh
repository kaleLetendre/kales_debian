# `theme` - browse and live-preview kitty terminal themes.
#
# kitty ships the picker as a kitten: it lists ~390 themes, previews each
# live in the current window as you scroll, and on selection writes the
# palette to ~/.config/kitty/current-theme.conf (which kitty.conf
# includes). Pass a name to switch non-interactively, e.g. `theme "Gruvbox
# Dark"`. Commit current-theme.conf afterwards to sync the choice.
alias theme='kitten themes'

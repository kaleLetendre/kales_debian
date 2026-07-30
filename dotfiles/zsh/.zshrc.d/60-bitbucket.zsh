# Bitbucket Cloud helpers.
# Put ~/bin on PATH so `bb-pr-comment` and friends are runnable.
if [[ -d "$HOME/bin" ]]; then
    path=("$HOME/bin" $path)
fi

# Load Bitbucket credentials from an untracked, private file (mode 600).
# The secret lives outside the dotfiles repo so it is never committed.
if [[ -f "$HOME/.config/bitbucket/env" ]]; then
    source "$HOME/.config/bitbucket/env"
fi

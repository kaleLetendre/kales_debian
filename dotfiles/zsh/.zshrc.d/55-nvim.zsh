# Neovim as the editor, plus the toolchain PATHs it depends on.
# Installed by setup/69-neovim.sh; config lives in dotfiles/nvim/.

# git, systemctl edit, crontab and friends all obey $EDITOR. $VISUAL is
# what the ones that distinguish "full screen editor" from "line editor"
# look at first, so set both to the same thing.
if command -v nvim >/dev/null; then
    export EDITOR=nvim
    export VISUAL=nvim
    # Muscle memory. `vim` and `vi` on this machine are the real vim only
    # if something installed it; aliasing means one editor, one config.
    alias vim=nvim
    alias vi=nvim
fi

# rustup installs with --no-modify-path in setup/69-neovim.sh, on purpose:
# PATH is owned by these bricks, not by an installer appending to .zshrc.
# This is where cargo, rustc, clippy and rust-analyzer live.
if [[ -d "$HOME/.cargo/bin" ]]; then
    path=("$HOME/.cargo/bin" $path)
fi

# `go install` drops binaries in $GOPATH/bin (default ~/go/bin). Mason
# installs gopls and delve into its own directory, but anything you install
# by hand lands here.
if [[ -d "$HOME/go/bin" ]]; then
    path=("$HOME/go/bin" $path)
fi

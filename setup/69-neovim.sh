#!/usr/bin/env bash
# 69-neovim.sh - Neovim as a terminal IDE, on a LazyVim base. Idempotent.
#
# Why not `apt-get install neovim`: Debian 13 ships 0.10.4, and current
# LazyVim (plus most of its plugin ecosystem) needs 0.11+. So we pin an
# upstream release tarball under /opt and symlink it onto PATH. Bump
# NVIM_VERSION to upgrade; the previous /opt tree is left alone, so undoing
# a bad bump is one symlink away.
#
# The config itself lives in dotfiles/nvim/ and is stowed to ~/.config/nvim.
# Plugins are NOT vendored here: lazy.nvim installs them and pins exact
# commits in lazy-lock.json. Because the stow symlink points back at this
# repo, that lockfile is written straight into dotfiles/nvim/.config/nvim/ --
# commit it and plugin versions become reproducible too.
#
# Section 5 finishes the job headlessly (plugins, treesitter parsers,
# language servers) so a fresh machine has a working editor when
# bootstrap.sh exits, with no manual first-launch step.
#
# Numbered 69 so it sits with the other editors (70-vscode, 71-dbeaver).

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

# Pinned upstream versions. Both are plain GitHub release tags.
NVIM_VERSION="v0.12.4"
NERD_FONT_VERSION="v3.5.0"

# --- 1. tools the config shells out to ---------------------------------
#   ripgrep          - live grep (<leader>sg) and most search pickers
#   fd-find          - the file picker (<leader>ff, <leader><space>)
#   unzip/curl/git   - how Mason fetches and unpacks language servers
#   build-essential  - treesitter compiles each parser with cc at install
#   xclip            - system clipboard bridge on X11 (this machine is X11)
#   lazygit          - the git UI LazyVim opens on <leader>gg
log "installing support tools"
$SUDO apt-get install -y ripgrep fd-find unzip curl git build-essential xclip lazygit

# Debian installs fd as `fdfind` to dodge a name clash with the old fdclone
# package. Plugins look for `fd` first and only some know about `fdfind`,
# so give them the name they expect.
if [[ ! -e /usr/local/bin/fd ]]; then
    log "linking fdfind -> /usr/local/bin/fd"
    $SUDO ln -s "$(command -v fdfind)" /usr/local/bin/fd
fi

# --- 2. neovim itself ---------------------------------------------------
NVIM_PREFIX="/opt/nvim-$NVIM_VERSION"
if [[ ! -x "$NVIM_PREFIX/bin/nvim" ]]; then
    log "installing neovim $NVIM_VERSION into $NVIM_PREFIX"
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/nvim.tar.gz" \
        "https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/nvim-linux-x86_64.tar.gz"
    tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
    # rm first so a half-extracted tree from an interrupted run can't
    # poison the new one. The path is a fixed literal, not user input.
    $SUDO rm -rf "$NVIM_PREFIX"
    $SUDO mv "$tmp/nvim-linux-x86_64" "$NVIM_PREFIX"
    rm -rf "$tmp"
else
    log "neovim $NVIM_VERSION already present"
fi
# -n so this replaces the symlink itself rather than following it and
# dropping a link *inside* the old install directory.
$SUDO ln -sfn "$NVIM_PREFIX/bin/nvim" /usr/local/bin/nvim

# --- 3. a Nerd Font -----------------------------------------------------
# LazyVim's file tree, statusline, and git gutter all draw glyphs from the
# Nerd Font private use area. Without a patched font every icon renders as
# a replacement box. Debian has no Nerd Font package, so pull the release.
FONT_DIR="/usr/local/share/fonts/JetBrainsMonoNerdFont"
if [[ ! -d "$FONT_DIR" ]]; then
    log "installing JetBrainsMono Nerd Font $NERD_FONT_VERSION"
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/font.tar.xz" \
        "https://github.com/ryanoasis/nerd-fonts/releases/download/$NERD_FONT_VERSION/JetBrainsMono.tar.xz"
    $SUDO mkdir -p "$FONT_DIR"
    $SUDO tar -xJf "$tmp/font.tar.xz" -C "$FONT_DIR"
    rm -rf "$tmp"
    $SUDO fc-cache -f "$FONT_DIR"
else
    log "JetBrainsMono Nerd Font already installed"
fi

# --- 4. language toolchains --------------------------------------------
# Only the compilers/runtimes go here. The language *servers* themselves
# (gopls, delve, ...) are installed by Mason on first nvim launch, into
# ~/.local/share/nvim/mason -- but Mason can only build them if the
# underlying toolchain is already on PATH, which is what this section is for.

# C/C++: clangd is the LSP, clang-format the formatter, gdb the debug
# backend behind nvim-dap.
log "installing C/C++ toolchain"
$SUDO apt-get install -y clangd clang-format gdb

# Go: Debian 13 ships Go 1.24, recent enough for gopls and delve.
log "installing Go toolchain"
$SUDO apt-get install -y golang-go

# Rust: via rustup, not apt. Debian freezes rustc at 1.85 (Feb 2025) and
# real crates outrun that quickly; rustup also keeps rust-analyzer pinned
# to the same toolchain as the compiler, which apt cannot promise.
# --no-modify-path because PATH belongs to dotfiles/zsh/.zshrc, not to
# rustup's own shell hook. Runs as the invoking user, into ~/.cargo.
if [[ ! -x "$HOME/.cargo/bin/rustup" ]]; then
    log "installing rustup"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --no-modify-path
else
    log "rustup already installed"
fi
# Idempotent: rustup reports "up to date" and exits 0 if already added.
log "adding rust-analyzer, clippy, rustfmt"
"$HOME/.cargo/bin/rustup" component add rust-analyzer clippy rustfmt

# --- 5. provision the config -------------------------------------------
# Install plugins, treesitter parsers and language servers now, so nvim is
# usable the moment bootstrap.sh finishes instead of spending its first
# interactive launch downloading while you wait.
#
# This needs ~/.config/nvim to exist, and bootstrap.sh does not stow
# dotfiles until *after* every setup module has run. So stow this one
# package early. `stow -R` is a re-stow: idempotent, and the later
# bootstrap-wide pass over the same package is then a no-op.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log "stowing the nvim config"
(cd "$REPO_DIR/dotfiles" && stow -t "$HOME" -R nvim)

# Plugins first, and blocking: `Lazy! sync` (with the bang) runs to
# completion rather than handing back to an interactive UI.
log "installing plugins"
nvim --headless "+Lazy! sync" +qa

# Then treesitter parsers and Mason's language servers. See the comments in
# 69-neovim-provision.lua for why this cannot just be `nvim --headless +qa`:
# LazyVim's setup never fires without a UI, and Mason's installs are async,
# so the pass has to trigger both and then wait for them to settle.
log "installing treesitter parsers and language servers"
nvim --headless -c "source $REPO_DIR/setup/69-neovim-provision.lua"

echo
echo "  neovim ready. Press <space>? inside nvim for the cheatsheet."
echo "  Run :checkhealth to confirm everything resolved."

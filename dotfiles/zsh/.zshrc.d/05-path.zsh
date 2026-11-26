# Prepend ~/.local/bin to PATH so user-local CLI installs (pipx, venv
# symlinks, language toolchain shims) take precedence over system bins.
if [[ -d "$HOME/.local/bin" ]]; then
    path=("$HOME/.local/bin" $path)
fi

# Rust toolchain from rustup (server/51-rust.sh). Installed with
# --no-modify-path, so the PATH entry lives here instead of in rc files.
if [[ -d "$HOME/.cargo/bin" ]]; then
    path=("$HOME/.cargo/bin" $path)
fi

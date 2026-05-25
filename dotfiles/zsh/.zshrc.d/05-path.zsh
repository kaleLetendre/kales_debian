# Prepend ~/.local/bin to PATH so user-local CLI installs (pipx, venv
# symlinks, language toolchain shims) take precedence over system bins.
if [[ -d "$HOME/.local/bin" ]]; then
    path=("$HOME/.local/bin" $path)
fi

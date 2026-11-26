#!/usr/bin/env bash
# server/50-dev-toolchain.sh - compilers, debuggers, profilers and CLI tools
# for the dev work done on the server. Idempotent.
#
# C/C++:
#   g++ clang         - both compilers; aseprite (server/53) builds with clang
#   clangd            - C/C++ language server for editors
#   clang-format      - C/C++ formatter
#   cmake ninja-build - build system + fast generator
#   gdb               - debugger
# Profiling:
#   linux-perf        - `perf` CPU profiler (cargo-flamegraph uses it too)
#   heaptrack         - heap allocation profiler
# Other languages:
#   golang-go         - Go toolchain
#   python3-tk        - Tk bindings for Python GUIs / matplotlib's TkAgg
#   python3-prompt-toolkit - system copy for scripts run with /usr/bin/python3
# CLI:
#   ripgrep fd-find   - fast grep / find (`rg`, `fdfind`)
#   xclip             - pipe to/from the X clipboard
#   lazygit           - terminal UI for git
#   crudini           - read/edit INI files from scripts
#   git-lfs           - large-file storage for git repos that use it

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

log "apt update"
$SUDO apt-get update

log "dev toolchain"
$SUDO apt-get install -y \
    g++ clang clangd clang-format cmake ninja-build gdb \
    linux-perf heaptrack \
    golang-go python3-tk python3-prompt-toolkit \
    ripgrep fd-find xclip lazygit crudini git-lfs

# Debian ships fd as `fdfind` (name clash with an older `fd` package);
# give it its usual name.
if [[ ! -e /usr/local/bin/fd ]]; then
    log "linking fd -> fdfind"
    $SUDO ln -s /usr/bin/fdfind /usr/local/bin/fd
fi

# Hook LFS into ~/.gitconfig (adds the filter.lfs section). Safe to repeat.
git lfs install --skip-repo

#!/usr/bin/env bash
# server/51-rust.sh - Rust via rustup (stable + nightly) and cargo-flamegraph.
# Idempotent. Per-user install under ~/.rustup and ~/.cargo, no sudo.
#
# rustup instead of Debian's rustc: Debian's lags upstream by many releases,
# and nightly (needed for miri and some unstable flags) isn't packaged at all.
# --no-modify-path: ~/.cargo/bin goes on PATH via the zsh config, not by
# letting the installer append to rc files behind stow's back.
#
# cargo-flamegraph wraps `perf` (server/50 installs linux-perf).

set -euo pipefail

log() { printf "  -> %s\n" "$*"; }

export PATH="$HOME/.cargo/bin:$PATH"

if ! command -v rustup >/dev/null 2>&1; then
    log "installing rustup (stable)"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --no-modify-path --default-toolchain stable
else
    log "rustup already installed"
fi

# Install only if missing: `toolchain install` on an existing toolchain
# upgrades it, which a bootstrap re-run shouldn't do behind your back.
# Update deliberately with `rustup update`.
if ! rustup toolchain list | grep -q '^nightly-'; then
    log "installing nightly toolchain"
    rustup toolchain install nightly --profile minimal --no-self-update
else
    log "nightly already installed"
fi

if ! cargo install --list | grep -q '^flamegraph '; then
    log "cargo install flamegraph"
    cargo install flamegraph
else
    log "flamegraph already installed"
fi

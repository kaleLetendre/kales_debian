#!/usr/bin/env bash
# server/53-aseprite.sh - build Aseprite (pixel-art editor) from source.
# Idempotent: skips the build when the binary already exists.
#
# Why from source: Aseprite is paid as a binary but the source is available
# and the EULA allows building it for personal use. This follows upstream's
# INSTALL.md for Linux: clang + libstdc++, Ninja, and the *prebuilt* Skia that
# aseprite publishes (building Skia yourself is a multi-hour detour).
#
# Layout (matches what the live server already has):
#   ~/aseprite-src           - git clone, with submodules
#   ~/aseprite-src/build     - cmake build dir; bin/aseprite + bin/data/
#   ~/deps/skia              - unpacked Skia-Linux-Release-x64 for SKIA_TAG
#   ~/.local/bin/aseprite    - wrapper exec'ing the real binary, so it keeps
#                              finding data/ next to itself
#
# SKIA_TAG must match laf/misc/skia-tag.txt in the aseprite checkout; bump
# both together if you pull a newer aseprite.
#
# Build deps: compilers come from server/50; the X11/GL/fontconfig headers
# are listed here because only this build needs them.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

SRC="$HOME/aseprite-src"
SKIA_DIR="$HOME/deps/skia"
SKIA_TAG="m124-08a5439a6b"
WRAPPER="$HOME/.local/bin/aseprite"

log "aseprite build deps"
$SUDO apt-get install -y \
    g++ clang cmake ninja-build unzip curl \
    libx11-dev libxcursor-dev libxi-dev libxrandr-dev \
    libgl1-mesa-dev libfontconfig1-dev

if [[ ! -d "$SRC/.git" ]]; then
    log "cloning aseprite"
    git clone --recursive https://github.com/aseprite/aseprite.git "$SRC"
fi

if [[ ! -f "$SKIA_DIR/out/Release-x64/libskia.a" ]]; then
    log "downloading prebuilt Skia $SKIA_TAG"
    tmpzip="$(mktemp --suffix=.zip)"
    curl -fL -o "$tmpzip" \
        "https://github.com/aseprite/skia/releases/download/$SKIA_TAG/Skia-Linux-Release-x64.zip"
    mkdir -p "$SKIA_DIR"
    unzip -q -o "$tmpzip" -d "$SKIA_DIR"
    rm -f "$tmpzip"
fi

if [[ ! -x "$SRC/build/bin/aseprite" ]]; then
    log "building aseprite (takes a while)"
    mkdir -p "$SRC/build"
    cd "$SRC/build"
    cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_CXX_FLAGS:STRING=-stdlib=libstdc++ \
        -DCMAKE_EXE_LINKER_FLAGS:STRING=-stdlib=libstdc++ \
        -DLAF_BACKEND=skia \
        -DSKIA_DIR="$SKIA_DIR" \
        -DSKIA_LIBRARY_DIR="$SKIA_DIR/out/Release-x64" \
        -DSKIA_LIBRARY="$SKIA_DIR/out/Release-x64/libskia.a" \
        ..
    ninja aseprite
else
    log "aseprite already built"
fi

if [[ ! -x "$WRAPPER" ]]; then
    log "writing $WRAPPER"
    mkdir -p "$(dirname "$WRAPPER")"
    cat > "$WRAPPER" <<'EOF'
#!/bin/bash
# Wrapper for the self-compiled Aseprite. Calls the binary at its real path so
# Aseprite still finds its data/ directory alongside it.
exec "$HOME/aseprite-src/build/bin/aseprite" "$@"
EOF
    chmod +x "$WRAPPER"
fi

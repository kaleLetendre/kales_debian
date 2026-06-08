#!/usr/bin/env bash
# 05-apt-components.sh - Enable 'contrib' and 'non-free' on the official
# Debian archives. Required for packages like nvidia-driver and
# nvidia-open-kernel-dkms that live outside 'main'. Trixie's netinst leaves
# only 'main non-free-firmware' enabled, which is not enough.
#
# Runs early (before 10-*, before the hardware layer) so every later module
# sees the extra components. Idempotent: only rewrites a sources file when a
# component is actually missing, and only touches lines pointing at the
# official Debian or Debian security archives -- third-party repos in
# sources.list.d/ are left alone.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

COMPONENTS=(contrib non-free)
changed=0

# Classic one-line .list format: /etc/apt/sources.list and *.list files.
# Strategy: for each official-archive deb/deb-src line that does not yet have
# component $c as a whole word, append " $c" at end of line. The (^|space)
# ... (space|$) anchors avoid matching 'non-free' inside 'non-free-firmware'.
for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
    [[ -f "$f" ]] || continue
    grep -qE '^[[:space:]]*deb(-src)?[[:space:]].*(deb\.debian\.org|security\.debian\.org)' "$f" || continue
    for c in "${COMPONENTS[@]}"; do
        # Are there any official-archive lines still missing this component?
        missing=$(sed -nE \
            "/^[[:space:]]*deb(-src)?[[:space:]].*(deb\.debian\.org|security\.debian\.org)/ { /(^|[[:space:]])${c}([[:space:]]|\$)/! p }" \
            "$f")
        if [[ -n "$missing" ]]; then
            log "adding '$c' to $f"
            $SUDO sed -i -E \
                "/^[[:space:]]*deb(-src)?[[:space:]].*(deb\.debian\.org|security\.debian\.org)/ { /(^|[[:space:]])${c}([[:space:]]|\$)/! s/\$/ ${c}/ }" \
                "$f"
            changed=1
        fi
    done
done

# Modern deb822 format (*.sources). Trixie's netinst still uses .list, but
# newer installers may switch. Only touch files whose URIs point at the
# official Debian archives -- never third-party ones (vivaldi, etc.).
for f in /etc/apt/sources.list.d/*.sources; do
    [[ -f "$f" ]] || continue
    grep -qE '^[[:space:]]*URIs:.*(deb\.debian\.org|security\.debian\.org)' "$f" || continue
    for c in "${COMPONENTS[@]}"; do
        if ! grep -qE "^[[:space:]]*Components:.*(^|[[:space:]])${c}([[:space:]]|\$)" "$f"; then
            log "adding '$c' to $f"
            $SUDO sed -i -E "s/^([[:space:]]*Components:.*)\$/\\1 ${c}/" "$f"
            changed=1
        fi
    done
done

if (( changed )); then
    log "apt update (sources changed)"
    $SUDO apt-get update
else
    log "components already enabled"
fi

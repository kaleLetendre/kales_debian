#!/usr/bin/env bash
# 83-dev-libs.sh - development libraries (-dev headers + libs) to build
# against common C dependencies. Idempotent.
#
# Kept separate from 20-base-packages.sh (runtime CLI tools) so the
# "what do I compile/link against" list lives in one place. apt-get
# update mirrors the other install modules so this is safe to run on its
# own, not just inside a full bootstrap.
#
# libsqlite3-dev       - SQLite C headers + lib; embedded SQL database
# librabbitmq-dev      - rabbitmq-c client headers + lib; AMQP from C
# libssl-dev           - OpenSSL headers + lib; TLS/crypto
# libcurl4-openssl-dev - libcurl headers + lib (OpenSSL flavor); HTTP client

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SUDO=""
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

log() { printf "  -> %s\n" "$*"; }

log "apt update"
$SUDO apt-get update

log "development libraries"
$SUDO apt-get install -y \
    libsqlite3-dev \
    librabbitmq-dev \
    libssl-dev \
    libcurl4-openssl-dev

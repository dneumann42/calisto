#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "${0%/*}" && pwd)"

"$SCRIPT_DIR/dev.sh"

exec env LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so lua "$SCRIPT_DIR/main.lua"

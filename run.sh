#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "${0%/*}" && pwd)"

"$SCRIPT_DIR/dev.sh"

exec nix run "$SCRIPT_DIR"

#!/usr/bin/env bash
# Installs Nix on Arch or Fedora if not already present.
# All runtime deps (lua, lgi, gtk4, gtk4-layer-shell …) are provided by
# the flake — no manual package or luarocks steps needed.
set -eu

# ---------------------------------------------------------------
# detect distro
# ---------------------------------------------------------------
if command -v pacman &>/dev/null; then
    DISTRO=arch
elif command -v dnf &>/dev/null; then
    DISTRO=fedora
else
    echo "==> ERROR: neither pacman nor dnf found — unsupported distro"
    exit 1
fi

# ---------------------------------------------------------------
# install nix via package manager
# ---------------------------------------------------------------
if command -v nix &>/dev/null; then
    echo "==> nix already installed ($(nix --version))"
else
    echo "==> Installing nix…"
    case "$DISTRO" in
        arch)   sudo pacman -S --needed nix ;;
        fedora) sudo dnf install -y nix      ;;
    esac

    echo "==> Enabling nix-daemon…"
    sudo systemctl enable --now nix-daemon
fi

# ---------------------------------------------------------------
# enable flakes (idempotent)
# ---------------------------------------------------------------
NIX_CONF="$HOME/.config/nix/nix.conf"
if ! grep -q "flakes" "$NIX_CONF" 2>/dev/null; then
    mkdir -p "$HOME/.config/nix"
    echo "experimental-features = nix-command flakes" >> "$NIX_CONF"
    echo "==> Enabled flakes in $NIX_CONF"
fi

# ---------------------------------------------------------------
echo ""
echo "  nix develop   — open a dev shell (all deps from the flake)"
echo "  nix run .     — build and launch calisto"

#!/usr/bin/env bash
# Installs and builds all runtime dependencies for Calisto on Arch Linux.
set -eu

echo "==> System packages"
sudo pacman -S --needed \
    lua \
    luarocks \
    gtk4 \
    gtk4-layer-shell \
    gobject-introspection

# ---------------------------------------------------------------
# lgi — Lua GObject Introspection
#
# lgi 0.9.2 does not compile on Lua 5.4: lua_resume() gained a 4th
# parameter (nresults) in 5.4.  The src.rock bundles the full source
# under  lgi/  but luarocks make needs the rockspec and the Makefile
# in the same directory.  We unpack, copy the rockspec down, patch
# the one call site, and build.
# ---------------------------------------------------------------
if lua -e 'require("lgi")' 2>/dev/null; then
    echo "==> lgi already installed"
else
    echo ""
    echo "==> Building lgi (patched for Lua 5.4)"

    BUILD=$(mktemp -d)
    trap 'rm -rf "$BUILD"' EXIT
    cd "$BUILD"

    luarocks download lgi
    unzip -q *.src.rock                          # rockspec + lgi/

    # rockspec lives at the top; Makefile lives inside lgi/ — move it down
    cp *.rockspec lgi/
    cd lgi

    # patch: lua_resume(L, from, narg)  →  lua_resume(L, from, narg, &nresults)
    sed -i \
        's/res = lua_resume (L, NULL, npos);/{ int nresults; res = lua_resume (L, NULL, npos, \&nresults); }/' \
        lgi/callable.c

    echo "==> Compiling lgi…"
    sudo luarocks make *.rockspec

    lua -e 'require("lgi"); print("lgi loaded OK")'
fi

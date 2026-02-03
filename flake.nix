{
  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs";
    flake-utils.url = "github:flake-utils/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # ── metadata — edit here; every package format derives from these ──
        pname       = "calisto";
        version     = "0.1.0";
        description = "Wayland top-panel for Sway / wlroots compositors";
        license     = "MIT";
        repoUrl     = "https://github.com/you/calisto";   # ← update this

        # ── nix deps ────────────────────────────────────────────────────────
        lua        = pkgs.lua5_4;
        lgi        = pkgs.lua54Packages.lgi;
        # ^ if lgi fails to build, apply the lua_resume() patch from dev.sh
        #   via an override on this derivation.
        gtk4       = pkgs.gtk4;
        layerShell = pkgs.gtk4-layer-shell;
        # ^ must exist in your nixpkgs — update or add an overlay if missing.
        gir        = pkgs.gobject-introspection;

        # ── only .lua files enter the store ──────────────────────────────────
        src = pkgs.lib.cleanSourceWith {
          src = ./.;
          filter = p: _t:
            builtins.elem (builtins.baseNameOf p)
              [ "main.lua" "gui.lua" "ui.lua" "widgets.lua"
                "theme.lua" "json.lua" "pprint.lua" ];
        };

        # ── data derivation — drops .lua files into /share/calisto/ ─────────
        calistoData = pkgs.stdenv.mkDerivation {
          pname   = pname + "-data";
          inherit version src;
          installPhase = ''
            mkdir -p "$out/share/${pname}"
            cp *.lua "$out/share/${pname}/"
          '';
        };

        # ── colon-separated GI typelib path (reused by every output) ─────────
        giTypelibs =
            "${gtk4}/lib/girepository-1.0"
          + ":${layerShell}/lib/girepository-1.0"
          + ":${pkgs.glib}/lib/girepository-1.0";

        # ── Arch PKGBUILD ────────────────────────────────────────────────────
        # Flush-left on purpose: nix strips indentation equal to the closing ''.
        # <<'WRAPPER' (quoted delimiter) stops bash from expanding $pkgdir,
        # $srcdir, and $@ during makepkg.  nix still interpolates ${pname} etc.
        pkgbuildText = ''
# Maintainer: you <you@example.com>
pkgname=${pname}
pkgver=${version}
pkgrel=1
pkgdesc="${description}"
arch=('x86_64')
url="${repoUrl}"
license=('${license}')
# lua-lgi is available in AUR.  If it does not compile with Lua 5.4
# apply the lua_resume() patch documented in dev.sh.
depends=('lua' 'gtk4' 'gtk4-layer-shell' 'gobject-introspection' 'lua-lgi')
source=("git+${repoUrl}.git")
md5sums=('SKIP')

build() { :; }  # pure Lua — nothing to compile

package() {
  local datadir="/usr/share/${pname}"
  mkdir -p "$pkgdir$datadir" "$pkgdir/usr/bin"

  install -m644 "$srcdir"/{main,gui,ui,widgets,theme,json,pprint}.lua \
    "$pkgdir$datadir/"

  cat > "$pkgdir/usr/bin/${pname}" <<'WRAPPER'
#!/bin/sh
exec env \
  LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so \
  LUA_PATH="/usr/share/${pname}/?.lua" \
  lua "/usr/share/${pname}/main.lua" "$@"
WRAPPER
  chmod +x "$pkgdir/usr/bin/${pname}"
}
'';

        # ── Fedora RPM spec ──────────────────────────────────────────────────
        # Same heredoc strategy.  rpmbuild expands %{…} macros on the whole
        # file before the shell runs, so %{name} inside <<'WRAPPER' works.
        # We use ${pname} (nix) in the wrapper paths for clarity.
        #
        # To generate Source0 before rpmbuild:
        #   git archive --prefix=calisto-0.1.0/ v0.1.0 | \
        #     gzip > calisto-0.1.0.tar.gz
        specText = ''
Name:           ${pname}
Version:        ${version}
Release:        1%{?dist}
Summary:        ${description}
License:        ${license}
URL:            ${repoUrl}
Source0:        %{name}-%{version}.tar.gz

# gtk4-layer-shell may require RPM Fusion on older Fedora releases
Requires:       lua
Requires:       gtk4-libs
Requires:       gtk4-layer-shell
Requires:       gobject-introspection
Requires:       lua-lgi

%description
${description}.
Built with Lua, LGI, and GTK 4.

%prep
%setup -q

%build
# pure Lua — nothing to compile

%install
mkdir -p %{buildroot}/usr/share/%{name} %{buildroot}/usr/bin
install -m644 main.lua gui.lua ui.lua widgets.lua \
              theme.lua json.lua pprint.lua \
              %{buildroot}/usr/share/%{name}/

cat > %{buildroot}/usr/bin/%{name} <<'WRAPPER'
#!/bin/sh
exec env \
  LD_PRELOAD=/usr/lib64/libgtk4-layer-shell.so \
  LUA_PATH="/usr/share/${pname}/?.lua" \
  lua "/usr/share/${pname}/main.lua" "$@"
WRAPPER
chmod 0755 %{buildroot}/usr/bin/%{name}

%files
/usr/bin/%{name}
%dir /usr/share/%{name}/
/usr/share/%{name}/*.lua

%changelog
* Tue Feb 03 2026 You <you@example.com> 0.1.0-1
- Initial packaging
'';

        # ── the runnable package (let-bound so apps.default can ref it) ────
        calistoPackage = pkgs.symlinkJoin {
          name  = pname;
          paths = [
            (pkgs.writeShellScriptBin pname ''
              exec env \
                GI_TYPELIB_PATH="${giTypelibs}" \
                LUA_PATH="${calistoData}/share/${pname}/?.lua;${lgi}/share/lua/5.4/?.lua" \
                LUA_CPATH="${lgi}/lib/lua/5.4/?.so" \
                LD_PRELOAD="${layerShell}/lib/libgtk4-layer-shell.so" \
                ${lua}/bin/lua "${calistoData}/share/${pname}/main.lua" "$@"
            '')
            calistoData
          ];
        };

      in {
        # ══════════════════════════════════════════════════════════
        #  nix build .   →  result/bin/calisto
        #  nix run .     →  launch directly
        # ══════════════════════════════════════════════════════════
        packages.default = calistoPackage;

        apps.default = {
          type    = "app";
          program = "${calistoPackage}/bin/${pname}";
        };

        # ══════════════════════════════════════════════════════════
        #  nix build .#pkgbuild   →  cat result   (Arch PKGBUILD)
        #  nix build .#specfile   →  cat result   (Fedora .spec)
        # ══════════════════════════════════════════════════════════
        packages.pkgbuild  = pkgs.writeText "PKGBUILD"      pkgbuildText;
        packages.specfile  = pkgs.writeText "${pname}.spec"  specText;

        # ══════════════════════════════════════════════════════════
        #  nix develop  →  shell with all runtime deps
        # ══════════════════════════════════════════════════════════
        devShells.default = pkgs.mkShell {
          buildInputs = [
            lua pkgs.luarocks gtk4 layerShell gir lgi pkgs.glib
          ];
          shellHook = ''
            export GI_TYPELIB_PATH="${giTypelibs}"
            export LUA_PATH="$PWD/?.lua;${lgi}/share/lua/5.4/?.lua"
            export LUA_CPATH="${lgi}/lib/lua/5.4/?.so"
            printf '\n  Run:  LD_PRELOAD=${layerShell}/lib/libgtk4-layer-shell.so lua main.lua\n\n'
          '';
        };
      }
    );
}

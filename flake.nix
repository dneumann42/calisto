{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      # replaces flake-utils.lib.eachSystem: maps system -> attrset, then
      # merges into { packages.x86_64-linux = …; packages.aarch64-linux = …; … }
      eachSystem = f:
        builtins.listToAttrs (map (s: { name = s; value = f s; }) systems);

      outputsFor = system:
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
          # lgi 0.9.2 is marked broken in nixpkgs: lua_resume() gained a 4th
          # arg (nresults) in Lua 5.4.  Import with allowBroken so eval passes,
          # then fix the one call site in postPatch (same fix as old dev.sh).
          lgi        = (import nixpkgs { inherit system; config.allowBroken = true; })
            .lua54Packages.lgi.overrideAttrs (prev: {
              postPatch = (prev.postPatch or "") + ''
                sed -i 's/res = lua_resume (L, NULL, npos);/{ int nresults; res = lua_resume (L, NULL, npos, \&nresults); }/' lgi/callable.c
              '';
            });
          gtk4       = pkgs.gtk4;
          layerShell = pkgs.gtk4-layer-shell;
          # ^ must exist in your nixpkgs — update or add an overlay if missing.
          gir        = pkgs.gobject-introspection;

          # ── only .lua files (and the src/ dir) enter the store ─────────
          src = pkgs.lib.cleanSourceWith {
            src = ./.;
            filter = p: t:
              t == "directory" || builtins.match ".*\\.lua$" (builtins.baseNameOf p) != null;
          };

          # ── data derivation — drops .lua files into /share/calisto/ ────────
          calistoData = pkgs.stdenv.mkDerivation {
            pname   = pname + "-data";
            inherit version src;
            installPhase = ''
              mkdir -p "$out/share/${pname}/src"
              cp calisto.lua "$out/share/${pname}/"
              cp src/*.lua   "$out/share/${pname}/src/"
            '';
          };

          # ── GI typelib path ─────────────────────────────────────────────
          # Typelibs live in .out outputs; propagatedBuildInputs only gives
          # one level.  Walk recursively (depth 5) to reach transitive deps
          # like HarfBuzz (dep of Pango, dep of GTK4).  Duplicates in the
          # path are harmless — GI silently skips dirs that don't exist.
          collectDeps = depth: deps:
            if depth == 0 then deps
            else
              let
                next = builtins.filter (d: d != null)
                  (builtins.concatMap
                    (d: (d.propagatedBuildInputs or [])) deps);
              in deps ++ collectDeps (depth - 1) next;
          giRaw   = collectDeps 5 [ gtk4 layerShell pkgs.glib ];
          giDeps  = builtins.map (d: if d ? "out" then d.out else d) giRaw;
          giTypelibs = builtins.concatStringsSep ":"
            (builtins.map (d: "${d}/lib/girepository-1.0") giDeps);

          # ── Arch PKGBUILD ──────────────────────────────────────────────────
          # Flush-left on purpose: nix strips indentation equal to the closing
          # ''.  <<'WRAPPER' (quoted delimiter) stops bash from expanding
          # $pkgdir / $srcdir / $@.  nix still interpolates ${pname} etc.
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

  install -m644 "$srcdir"/calisto.lua "$pkgdir$datadir/"
  mkdir -p "$pkgdir$datadir/src"
  install -m644 "$srcdir"/src/*.lua  "$pkgdir$datadir/src/"

  cat > "$pkgdir/usr/bin/${pname}" <<'WRAPPER'
#!/bin/sh
exec env \
  LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so \
  LUA_PATH="/usr/share/${pname}/?.lua:/usr/share/${pname}/src/?.lua" \
  lua "/usr/share/${pname}/calisto.lua" "$@"
WRAPPER
  chmod +x "$pkgdir/usr/bin/${pname}"
}
'';

          # ── Fedora RPM spec ────────────────────────────────────────────────
          # Same heredoc strategy.  rpmbuild expands %{…} macros on the whole
          # file before the shell runs, so %{name} inside <<'WRAPPER' works.
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
install -m644 calisto.lua %{buildroot}/usr/share/%{name}/
mkdir -p %{buildroot}/usr/share/%{name}/src
install -m644 src/*.lua  %{buildroot}/usr/share/%{name}/src/

cat > %{buildroot}/usr/bin/%{name} <<'WRAPPER'
#!/bin/sh
exec env \
  LD_PRELOAD=/usr/lib64/libgtk4-layer-shell.so \
  LUA_PATH="/usr/share/${pname}/?.lua:/usr/share/${pname}/src/?.lua" \
  lua "/usr/share/${pname}/calisto.lua" "$@"
WRAPPER
chmod 0755 %{buildroot}/usr/bin/%{name}

%files
/usr/bin/%{name}
%dir /usr/share/%{name}/
/usr/share/%{name}/calisto.lua
%dir /usr/share/%{name}/src/
/usr/share/%{name}/src/*.lua

%changelog
* Tue Feb 03 2026 You <you@example.com> 0.1.0-1
- Initial packaging
'';

          # ── the runnable package ───────────────────────────────────────────
          calistoPackage = pkgs.symlinkJoin {
            name  = pname;
            paths = [
              (pkgs.writeShellScriptBin pname ''
                exec env \
                  GI_TYPELIB_PATH="${giTypelibs}" \
                  LUA_PATH="${calistoData}/share/${pname}/?.lua;${calistoData}/share/${pname}/src/?.lua;${lgi}/share/lua/5.4/?.lua" \
                  LUA_CPATH="${lgi}/lib/lua/5.4/?.so" \
                  LD_PRELOAD="${layerShell}/lib/libgtk4-layer-shell.so" \
                  ${lua}/bin/lua "${calistoData}/share/${pname}/calisto.lua" "$@"
              '')
              calistoData
            ];
          };

        in {
          packages = {
            default  = calistoPackage;
            pkgbuild = pkgs.writeText "PKGBUILD"      pkgbuildText;
            specfile = pkgs.writeText "${pname}.spec"  specText;
          };

          apps.default = {
            type    = "app";
            program = "${calistoPackage}/bin/${pname}";
          };

          devShells.default = pkgs.mkShell {
            buildInputs = [
              lua pkgs.luarocks gtk4 layerShell gir lgi pkgs.glib
            ];
            shellHook = ''
              export GI_TYPELIB_PATH="${giTypelibs}"
              export LUA_PATH="$PWD/?.lua;$PWD/src/?.lua;${lgi}/share/lua/5.4/?.lua"
              export LUA_CPATH="${lgi}/lib/lua/5.4/?.so"
              printf '\n  Run:  LD_PRELOAD=${layerShell}/lib/libgtk4-layer-shell.so lua calisto.lua\n\n'
            '';
          };
        };

    in {
      packages   = eachSystem (s: (outputsFor s).packages);
      apps       = eachSystem (s: (outputsFor s).apps);
      devShells  = eachSystem (s: (outputsFor s).devShells);
    };
}

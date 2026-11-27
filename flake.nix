# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
#
# SPDX-License-Identifier: MIT
{
  description = "Wings 3D, V-Sekai-fire fork: Nix builds and the files that ORAS pushes";

  # One nixpkgs input, so a consumer can `follows` it.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # The macOS SDK is not redistributable and never lives in this repository. Override it locally:
  #   --override-input appleSdk path:/path/to/MacOSX26.5.sdk
  inputs.appleSdk = { url = "path:./nix/apple-sdk-placeholder"; flake = false; };

  outputs = { self, nixpkgs, appleSdk }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f s (import nixpkgs { system = s; overlays = [ self.overlays.default ]; }));
      mkMacNifs = pkgs: arch: pkgs.stdenv.mkDerivation {
        pname = "wings-nifs-macos-${arch}";
        version = "2.4.1";
        src = self;
        nativeBuildInputs = [ pkgs.erlang pkgs.llvmPackages.clang-unwrapped pkgs.llvmPackages.lld pkgs.llvmPackages.llvm ];
        dontConfigure = true;
        buildPhase = ''
          SDK=${appleSdk}
          test -d $SDK/usr/include || { echo "no SDK: pass --override-input appleSdk path:<MacOSX sdk dir>"; exit 1; }
          mkdir -p _deps/eigen _deps/libigl/include priv
          ln -s ${pkgs.eigen}/include/eigen3/* _deps/eigen/
          ln -s ${pkgs.libigl}/include/* _deps/libigl/include/
          F="-target ${arch}-apple-darwin -isysroot $SDK -mmacosx-version-min=13.0"
          cd c_src
          make OS=Darwin GCC="clang $F -fuse-ld=lld" WORDSIZE=64 \
            ERL_INC=${pkgs.erlang}/lib/erlang/usr/include \
            CFLAGS="-g -O2" \
            CXXFLAGS="-g -O2 -std=c++17 -stdlib=libc++ -x c++ -Wno-deprecated-declarations -Wno-unknown-pragmas -Wno-switch" \
            LIBS="-bundle -flat_namespace -undefined suppress" \
            CXX_LD="-stdlib=libc++"
          cd ..
        '';
        installPhase = "mkdir -p $out/priv && cp priv/*.so $out/priv/";
      };
    in {
      # nixpkgs' wings, built from this checkout (its plugins include wpc_cagefit).
      overlays.default = final: prev: {
        wings = prev.wings.overrideAttrs (_: { version = "2.4.1-v-sekai-fire"; src = self; patches = [ ]; });
      };

      packages = forAll (system: pkgs: rec {
        wings = pkgs.wings;
        default = wings;
        # The C parts of Wings (pick, tessellator, libigl) for Windows, cross-built with mingw (the same
        # mingw64 GCC as the org's crossbuild-fedora image). The beams are platform-independent: `wings`.
        # The C parts of Wings (pick, tessellator, libigl) for Windows, cross-built with llvm-mingw: clang 21 for
        # x86_64-w64-mingw32 with compiler-rt and libc++ (pkgsLLVM on pkgsCross.mingwW64). The beams are
        # platform-independent: they come from `wings`.
        windows-nifs = let st = pkgs.pkgsCross.mingwW64.pkgsLLVM.stdenv; in st.mkDerivation {
          pname = "wings-nifs-windows";
          version = "2.4.1";
          src = self;
          nativeBuildInputs = [ pkgs.erlang ];
          dontConfigure = true;
          buildPhase = ''
            mkdir -p _deps/eigen _deps/libigl/include priv
            ln -s ${pkgs.eigen}/include/eigen3/* _deps/eigen/
            ln -s ${pkgs.libigl}/include/* _deps/libigl/include/
            cd c_src
            make GCC=$CC USEMINGWGCC=true SO_EXT=dll LIBS=-shared WORDSIZE=64 \
              ERL_INC=${pkgs.erlang}/lib/erlang/usr/include \
              CFLAGS="-g -O2 -D__WIN32__" \
              CXXFLAGS="-g -O2 -D__WIN32__ -std=c++17 -x c++ -Wno-deprecated-declarations -Wno-unknown-pragmas -Wno-switch" \
              CXX_LD="-lc++"
            cd ..
          '';
          installPhase = "mkdir -p $out/priv && cp priv/*.dll $out/priv/";
        };
        # macOS NIFs, cross-built from Linux the way the godot repos do it (platform/macos/detect.py, APPLE_LLVM_CROSS):
        # clang with `-target <arch>-apple-darwin -isysroot <SDK>`, lld, llvm-ar. Needs the SDK input override.
        macos-arm64-nifs = mkMacNifs pkgs "arm64";
        macos-x86_64-nifs = mkMacNifs pkgs "x86_64";
        # The files ORAS pushes: one zstd tarball of the build, named by system.
        oras-files = pkgs.runCommand "wings-oras-files-${system}" { nativeBuildInputs = [ pkgs.zstd ]; } ''
          mkdir -p $out
          tar --sort=name --mtime=@1 --owner=0 --group=0 --numeric-owner -C ${wings} -cf - . | zstd -19 -T0 -o $out/wings-${system}.tar.zst
        '';
      });

      # nix run .#push -- ghcr.io/v-sekai-fire/wings:<tag>   (needs `oras login`)
      apps = forAll (system: pkgs: {
        push = {
          type = "app";
          program = toString (pkgs.writeShellScript "push" ''
            set -e
            ref=$1
            cd ${self.packages.${system}.oras-files}
            ${pkgs.oras}/bin/oras push "$ref-${system}" --artifact-type application/vnd.v-sekai-fire.wings.v1 wings-${system}.tar.zst:application/zstd
          '');
        };
      });
    };
}

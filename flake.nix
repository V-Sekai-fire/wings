# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
#
# SPDX-License-Identifier: MIT
{
  description = "Wings 3D, V-Sekai-fire fork: Nix builds and the files that ORAS pushes";

  # One nixpkgs input, so a consumer can `follows` it.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f s (import nixpkgs { system = s; overlays = [ self.overlays.default ]; }));
    in {
      # nixpkgs' wings, built from this checkout (its plugins include wpc_cagefit).
      overlays.default = final: prev: {
        wings = prev.wings.overrideAttrs (_: { version = "2.4.1-v-sekai-fire"; src = self; patches = [ ]; });
      };

      packages = forAll (system: pkgs: rec {
        wings = pkgs.wings;
        default = wings;
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

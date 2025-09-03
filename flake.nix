{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        lib =
          typixLib:
          import ./nix {
            inherit (pkgs) lib newScope;
            inherit typixLib;
          }
          // {
            hyptyp-typst = ./lib;
          };

        hyptypBin = (lib { }).hyptypBin;
      in
      rec {
        packages = {
          inherit hyptypBin;
          default = hyptypBin;
        };

        checks = packages;

        inherit lib;
      }
    );
}

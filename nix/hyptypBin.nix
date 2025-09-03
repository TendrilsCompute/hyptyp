{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  name = "hyptypBin";
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../bin
      ../Cargo.lock
      ../Cargo.toml
    ];
  };
  cargoLock.lockFile = "${src}/Cargo.lock";
}

{
  lib,
  newScope,
  typixLib,
}:
lib.makeScope newScope (
  self:
  let
    inherit (self) callPackage;
  in
  {
    hyptypBin = callPackage ./hyptypBin.nix { };
    buildHyptypProject = callPackage ./buildHyptypProject.nix { inherit typixLib; };
    watchHyptypProject = callPackage ./watchHyptypProject.nix { inherit typixLib; };
  }
)

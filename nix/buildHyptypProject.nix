{
  lib,
  typixLib,
  hyptypBin,
}:
args@{
  typstSource ? "main.typ",
  ...
}:
let
  typstOptsString =
    args.typstOptsString or (typixLib.typstOptsFromArgs (
      args
      // {
        typstOpts.format = [ ];
      }
    ));
in
typixLib.buildTypstProject (
  args
  // {
    nativeBuildInputs = (args.nativeBuildInputs or [ ]) ++ [
      hyptypBin
    ];
    buildPhaseTypstCommand =
      args.buildPhaseHyptypCommand or ''
        hyptyp compile ${lib.strings.escapeShellArg typstSource} "$out" -- ${typstOptsString}
      '';
  }
)

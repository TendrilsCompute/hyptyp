{
  lib,
  pkgs,
  typixLib,
  typst,
  hyptypBin,
}:
args@{
  emojiFont ? "default",
  fontPaths ? [ ],
  forceVirtualPaths ? false,
  typstSource ? "main.typ",
  typstWatchCommand ? "typst watch",
  virtualPaths ? [ ],
  ...
}:
let
  inherit (builtins) isNull removeAttrs;
  inherit (lib) lists optionalString;
  inherit (lib.strings) concatStringsSep toShellVars;

  emojiFontPath = typixLib.emojiFontPathFromString emojiFont;
  allFontPaths = fontPaths ++ lists.optional (!isNull emojiFontPath) emojiFontPath;
  typstOptsString =
    args.typstOptsString or (typixLib.typstOptsFromArgs (
      args
      // {
        typstOpts.format = [ ];
      }
    ));

  # unsetSourceDateEpochScript = builtins.readFile ./setupHooks/unsetSourceDateEpochScript.sh;

  cleanedArgs = removeAttrs args [
    "emojiFont"
    "fontPaths"
    "forceVirtualPaths"
    "scriptName"
    "text"
    "typstOpts"
    "typstOptsString"
    "typstOutput"
    "typstSource"
    "typstWatchCommand"
    "virtualPaths"
  ];
in
pkgs.writeShellApplication (
  cleanedArgs
  // {
    name = args.scriptName or args.name or "hyptyp-watch";

    runtimeInputs = (args.runtimeInputs or [ ]) ++ [
      pkgs.coreutils
      typst
      hyptypBin
    ];

    text =
      optionalString (allFontPaths != [ ]) ''
        export TYPST_FONT_PATHS=${concatStringsSep ":" allFontPaths}
      ''
      + optionalString (virtualPaths != [ ]) (
        typixLib.linkVirtualPaths {
          inherit virtualPaths forceVirtualPaths;
        }
      )
      + ''
        ${toShellVars { inherit typstSource; }}
        hyptyp watch "$typstSource" "$@" -- ${typstOptsString}
      '';
  }
)

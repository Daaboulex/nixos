# wine — Wine installation with variant selection and optional Bottles frontend.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.wine;
in
{
  options.myModules.home.wine = {
    enable = lib.mkEnableOption "Wine installation";
    variant = lib.mkOption {
      type = lib.types.enum [
        "stable"
        "staging"
        "stableFull"
        "stagingFull"
      ];
      default = "stagingFull";
      description = "Wine variant (staging has more patches, Full includes all optional deps)";
    };
    bottles.enable = lib.mkEnableOption "Bottles installation";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home.packages = [ pkgs.wineWow64Packages.${cfg.variant} ];
    })
    (lib.mkIf cfg.bottles.enable {
      home.packages = [ pkgs.bottles ];
    })
  ];
}

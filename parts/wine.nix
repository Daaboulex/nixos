{ inputs, ... }:
{
  flake.nixosModules.gaming-wine =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      wineCfg = config.myModules.gaming.wine;
      bottlesCfg = config.myModules.gaming.wine.bottles;
    in
    {
      _class = "nixos";
      options.myModules.gaming.wine = {
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
        (lib.mkIf wineCfg.enable {
          environment.systemPackages = [ pkgs.wineWow64Packages.${wineCfg.variant} ];
        })
        (lib.mkIf bottlesCfg.enable {
          environment.systemPackages = [ pkgs.bottles ];
        })
      ];
    };
}

{ inputs, ... }: {
  flake.nixosModules.apps-wine = { config, lib, pkgs, ... }: {
    options.myModules.programs.wine = {
      enable = lib.mkEnableOption "Enable Wine installation";
      variant = lib.mkOption { type = lib.types.enum [ "stable" "staging" "stableFull" "stagingFull" ]; default = "stagingFull"; description = "Wine variant (staging has more patches, Full includes all optional deps)"; };
    };
    options.myModules.programs.bottles.enable = lib.mkEnableOption "Enable Bottles installation";

    config = lib.mkMerge [
      (lib.mkIf config.myModules.programs.wine.enable {
        environment.systemPackages = [ pkgs.wineWow64Packages.${config.myModules.programs.wine.variant} ];
      })
      (lib.mkIf config.myModules.programs.bottles.enable {
        environment.systemPackages = [ pkgs.bottles ];
      })
    ];
  };
}

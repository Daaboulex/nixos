{ config, pkgs, lib, ... }:
{
  options.myModules.programs.wine.enable = lib.mkEnableOption "Enable Wine installation";
  options.myModules.programs.wine.variant = lib.mkOption {
    type = lib.types.enum [ "stable" "staging" "stableFull" "stagingFull" ];
    default = "stagingFull";
    description = "Wine variant to install";
  };
  options.myModules.programs.bottles.enable = lib.mkEnableOption "Enable Bottles installation";

  config = let
    wineEnabled = config.myModules.programs.wine.enable;
    variant = config.myModules.programs.wine.variant;
    winePkg = pkgs.wineWowPackages.${variant};
    bottlesEnabled = config.myModules.programs.bottles.enable;
    pkgList = (if wineEnabled then [ winePkg ] else [])
      ++ (if bottlesEnabled then [ pkgs.bottles ] else []);
  in {
    environment.systemPackages = pkgList;
  };
}
# Wine/Bottles: toggles for Wine WOW variant and Bottles
# Example:
#   myModules.programs.wine.enable = true;
#   myModules.programs.wine.variant = "staging";
#   myModules.programs.bottles.enable = true;
{ inputs, ... }: {
  flake.nixosModules.apps-wine = { config, lib, pkgs, ... }: {
    options.myModules.programs.wine = {
      enable = lib.mkEnableOption "Enable Wine installation";
      variant = lib.mkOption { type = lib.types.enum [ "stable" "staging" "stableFull" "stagingFull" ]; default = "stagingFull"; };
    };
    options.myModules.programs.bottles.enable = lib.mkEnableOption "Enable Bottles installation";

    config = let
      wineEnabled = config.myModules.programs.wine.enable;
      variant = config.myModules.programs.wine.variant;
      winePkg = pkgs.wineWow64Packages.${variant};
      bottlesEnabled = config.myModules.programs.bottles.enable;
      pkgList = (if wineEnabled then [ winePkg ] else []) ++ (if bottlesEnabled then [ pkgs.bottles ] else []);
    in {
      environment.systemPackages = pkgList;
    };
  };
}

{ inputs, ... }: {
  flake.nixosModules.hardware-graphics = { config, lib, pkgs, ... }: {
    options.myModules.hardware.graphics = {
      enable = lib.mkEnableOption "Graphics support";
      enable32Bit = lib.mkOption { type = lib.types.bool; default = true; description = "Enable 32-bit graphics support"; };
    };

    config = lib.mkIf config.myModules.hardware.graphics.enable {
      hardware.graphics = {
        enable = true;
        enable32Bit = config.myModules.hardware.graphics.enable32Bit;
      };
    };
  };
}

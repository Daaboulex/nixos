{ inputs, ... }: {
  flake.nixosModules.hardware-piper = { config, lib, pkgs, ... }: {
    options.myModules.hardware.piper.enable = lib.mkEnableOption "Piper mouse configuration tool and ratbagd service";

    config = lib.mkIf config.myModules.hardware.piper.enable {
      services.ratbagd.enable = true;
      environment.systemPackages = [ pkgs.piper ];
    };
  };
}

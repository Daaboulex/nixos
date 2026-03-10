{ inputs, ... }: {
  flake.nixosModules.hardware-piper = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.hardware.piper;
    in {
      _class = "nixos";
      options.myModules.hardware.piper.enable = lib.mkEnableOption "Piper mouse configuration tool and ratbagd service";

      config = lib.mkIf cfg.enable {
        services.ratbagd.enable = true;
        environment.systemPackages = [ pkgs.piper ];
      };
    };
}

{ config, pkgs, lib, ... }:

let
  cfg = config.myModules.hardware.piper;
in
{
  options.myModules.hardware.piper = {
    enable = lib.mkEnableOption "Piper mouse configuration tool and ratbagd service";
  };

  config = lib.mkIf cfg.enable {
    # Daemon required for configuring gaming mice
    services.ratbagd.enable = true;

    # GUI frontend for ratbagd
    environment.systemPackages = with pkgs; [
      piper
    ];
  };
}

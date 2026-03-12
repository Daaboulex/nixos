{ inputs, ... }:
{
  flake.nixosModules.hardware-bluetooth =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.hardware.bluetooth;
    in
    {
      _class = "nixos";
      options.myModules.hardware.bluetooth = {
        enable = lib.mkEnableOption "Bluetooth configuration";
        powerOnBoot = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Power on Bluetooth controller on boot";
        };
      };

      config = lib.mkIf cfg.enable {
        hardware.bluetooth = {
          enable = true;
          inherit (cfg) powerOnBoot;
          settings.General = {
            Enable = "Source,Sink,Media,Socket";
            Experimental = true;
          };
        };

        users.users.${config.myModules.primaryUser}.extraGroups = [ "bluetooth" ];
      };
    };
}

{ inputs, ... }: {
  flake.nixosModules.hardware-bluetooth = { config, lib, pkgs, ... }: {
    options.myModules.hardware.bluetooth = {
      enable = lib.mkEnableOption "Bluetooth configuration";
      powerOnBoot = lib.mkOption { type = lib.types.bool; default = false; description = "Power on Bluetooth controller on boot"; };
    };

    config = lib.mkIf config.myModules.hardware.bluetooth.enable {
      hardware.bluetooth = {
        enable = true;
        powerOnBoot = config.myModules.hardware.bluetooth.powerOnBoot;
        settings.General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
      
      # Add user to bluetooth group
      users.users.${config.myModules.primaryUser}.extraGroups = [ "bluetooth" ];
    };
  };
}

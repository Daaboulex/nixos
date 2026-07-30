# mbpfan — mbpfan daemon for MacBook fan control via applesmc.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.hardware.mbpfan;
    in
    {
      _class = "nixos";
      options.myModules.hardware.mbpfan = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "mbpfan daemon for MacBook fan control";
        };
        lowTemp = lib.mkOption {
          type = lib.types.int;
          default = 45;
          description = "Temperature to start ramping fan (Celsius)";
        };
        highTemp = lib.mkOption {
          type = lib.types.int;
          default = 65;
          description = "Temperature for high fan speed (Celsius)";
        };
        maxTemp = lib.mkOption {
          type = lib.types.int;
          default = 80;
          description = "Maximum temperature before full fan (Celsius)";
        };
        pollingInterval = lib.mkOption {
          type = lib.types.int;
          default = 1;
          description = "Fan polling interval in seconds";
        };
      };
      config = lib.mkIf cfg.enable {
        services.mbpfan = {
          enable = true;
          verbose = false;
          settings.general = {
            low_temp = cfg.lowTemp;
            high_temp = cfg.highTemp;
            max_temp = cfg.maxTemp;
            polling_interval = cfg.pollingInterval;
          };
        };
      };
    };
in
{
  flake.modules.nixos.hardware-mbpfan = mod;

}

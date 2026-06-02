# evdev — evdev input passthrough for keyboard/mouse to VFIO guests.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.myModules.vfio;
    in
    {
      _class = "nixos";

      options.myModules.vfio.evdev = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Evdev input passthrough for keyboard/mouse";
        };
        keyboardPath = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Path to keyboard event device (e.g. /dev/input/by-id/...)";
        };
        mousePath = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Path to mouse event device (e.g. /dev/input/by-id/...)";
        };
      };

      config = lib.mkIf (cfg.enable && cfg.evdev.enable) {
        services.udev.extraRules = ''
          SUBSYSTEM=="misc", KERNEL=="uinput", MODE="0660", GROUP="input"
        '';
      };
    };
in
{
  flake.modules.nixos.vfio-evdev = mod;

}

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
          description = "Path to primary keyboard event device (e.g. /dev/input/by-id/...)";
        };
        extraKeyboardPaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional keyboard event devices to pass through (multi-interface keyboards like the Ducky wireless expose multiple event nodes that all need to be passed)";
        };
        mousePath = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Path to mouse event device (e.g. /dev/input/by-id/...)";
        };
      };

      config = lib.mkIf (cfg.enable && cfg.evdev.enable) {
        # Enabling evdev with no device paths emits nothing -- every -object
        # input-linux arg in vms.nix is null-gated, so it is a silent no-op.
        # Require at least one path so an enabled passthrough actually passes.
        assertions = [
          {
            assertion =
              cfg.evdev.keyboardPath != null
              || cfg.evdev.extraKeyboardPaths != [ ]
              || cfg.evdev.mousePath != null;
            message = "myModules.vfio.evdev: enabled but no device paths set (keyboardPath / extraKeyboardPaths / mousePath all empty) -- it would pass nothing. Set a path or disable evdev.";
          }
        ];
        services.udev.extraRules = ''
          SUBSYSTEM=="misc", KERNEL=="uinput", MODE="0660", GROUP="input"
        '';
      };
    };
in
{
  flake.modules.nixos.vfio-evdev = mod;

}

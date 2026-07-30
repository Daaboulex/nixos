# yeetmouse — YeetMouse kernel mouse acceleration driver.
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
      cfg = config.myModules.input.yeetmouse;
      # Build yeetmouse directly from the flake input's package.nix,
      # bypassing the overlay to avoid Nix eval caching issues with dirty trees
      basePkg = pkgs.callPackage "${inputs.yeetmouse-nix}/package.nix" {
        inherit (inputs.yeetmouse-nix.inputs) yeetmouse-src;
        inherit (config.boot.kernelPackages) kernel;
      };
    in
    {
      _class = "nixos";

      options.myModules.input.yeetmouse = {
        enable = lib.mkEnableOption "YeetMouse kernel mouse acceleration driver";

        devices.g502 = {
          enable = lib.mkEnableOption "Libinput flat acceleration profile for Logitech G502 (prevents double acceleration)";

          wiredProductId = lib.mkOption {
            type = lib.types.str;
            default = "c08d";
            description = "USB product ID for the wired G502";
          };

          wirelessProductId = lib.mkOption {
            type = lib.types.str;
            default = "c539";
            description = "USB product ID for the Lightspeed Receiver";
          };

          dpi = lib.mkOption {
            type = lib.types.int;
            default = 1600;
            description = "Mouse DPI setting (reported to libinput via HWDB)";
          };

          pollingRate = lib.mkOption {
            type = lib.types.int;
            default = 1000;
            description = "Mouse polling rate in Hz";
          };
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          # Enable the upstream yeetmouse driver with direct package reference
          {
            hardware.yeetmouse.enable = true;
            hardware.yeetmouse.package = basePkg;
            # Force-load at boot whenever yeetmouse is enabled (NOT gated on the
            # g502 HWDB sub-feature) -- the driver must load even with no G502.
            boot.kernelModules = [ "yeetmouse" ];
          }

          # G502 libinput HWDB — force flat acceleration profile to prevent
          # libinput from stacking acceleration on top of YeetMouse's curve
          (lib.mkIf cfg.devices.g502.enable (
            let
              inherit (cfg.devices) g502;
              inherit (lib) toUpper;
            in
            {
              services.udev.extraHwdb = ''
                # Logitech G502 Lightspeed Receiver
                evdev:input:b0003v046Dp${toUpper g502.wirelessProductId}*
                 MOUSE_DPI=${toString g502.dpi}@${toString g502.pollingRate}
                 ID_INPUT_MOUSE_ACCEL_PROFILE=flat

                # Logitech G502 Wired
                evdev:input:b0003v046Dp${toUpper g502.wiredProductId}*
                 MOUSE_DPI=${toString g502.dpi}@${toString g502.pollingRate}
                 ID_INPUT_MOUSE_ACCEL_PROFILE=flat

                # Kernel-exposed input device ID (0x407F)
                evdev:input:b0003v046Dp407F*
                 MOUSE_DPI=${toString g502.dpi}@${toString g502.pollingRate}
                 ID_INPUT_MOUSE_ACCEL_PROFILE=flat

                # Generic fallback by name for any G502 variant
                evdev:name:Logitech G502*
                 MOUSE_DPI=${toString g502.dpi}@${toString g502.pollingRate}
                 ID_INPUT_MOUSE_ACCEL_PROFILE=flat
              '';
            }
          ))
        ]
      );
    };
in
{
  flake.modules.nixos.input-yeetmouse = mod;

}

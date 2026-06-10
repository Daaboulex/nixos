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
      # Device scoping. yeetmouse is a GLOBAL kernel input_handler with no runtime
      # device knob — its only device gate is driver_match() in driver.c. When
      # onlyDevices is set, inject a guard ahead of driver_match's accept paths so
      # any device whose input-level vid:pid is not in the list is rejected (left
      # untouched). Build-time, so changing the list rebuilds the module.
      mkCond = d: "(dev->id.vendor == 0x${d.vendorId} && dev->id.product == 0x${d.productId})";
      deviceGuard = lib.concatMapStringsSep " || " mkCond cfg.onlyDevices;
      yeetmousePkg =
        if cfg.onlyDevices == [ ] then
          basePkg
        else
          basePkg.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              # Fail loudly if the anchor moved upstream, rather than silently
              # shipping a build that grabs every mouse.
              grep -q 'dev->dev.parent->bus == &hid_bus_type' driver/driver.c \
                || { echo "yeetmouse onlyDevices: driver_match anchor not found — upstream changed; refusing to ship an unfiltered module" >&2; exit 1; }
              awk '/dev->dev.parent->bus == &hid_bus_type/ && !inj { print "    if (!(${deviceGuard})) return false;"; inj=1 } { print }' \
                driver/driver.c > driver/driver.c.tmp && mv driver/driver.c.tmp driver/driver.c
            '';
          });
    in
    {
      _class = "nixos";

      options.myModules.input.yeetmouse = {
        enable = lib.mkEnableOption "YeetMouse kernel mouse acceleration driver";

        onlyDevices = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                vendorId = lib.mkOption {
                  type = lib.types.strMatching "[0-9a-fA-F]{1,4}";
                  description = ''USB vendor id (hex, no "0x"), e.g. "046d".'';
                };
                productId = lib.mkOption {
                  type = lib.types.strMatching "[0-9a-fA-F]{1,4}";
                  description = ''
                    Input-level product id (hex, no "0x") as the kernel input device
                    reports it — may differ from the USB/receiver id (a Logitech
                    Lightspeed mouse can enumerate as c539 or 407f). Confirm against
                    /proc/bus/input/devices.
                  '';
                };
              };
            }
          );
          default = [ ];
          description = ''
            Restrict the yeetmouse driver to ONLY these input devices; every other
            mouse is left untouched (no acceleration). Empty (default) = all mice.
            Patches driver_match at build time, so changing the list rebuilds the
            module. Use to give one seat's mouse the accel curve while a second
            seat's mouse stays flat.
          '';
        };

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
            hardware.yeetmouse.package = yeetmousePkg;
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

              boot.kernelModules = [ "yeetmouse" ];
            }
          ))
        ]
      );
    };
in
{
  flake.modules.nixos.input-yeetmouse = mod;

}

# Logitech G502 libinput HWDB configuration for YeetMouse
#
# This module ONLY handles the libinput flat acceleration profile via HWDB.
# Actual mouse acceleration parameters (sensitivity, mode, rotation, etc.)
# are configured through the upstream `hardware.yeetmouse` options in driver.nix,
# which writes them to sysfs via its own udev mechanism.
#
# The HWDB entries are critical: without forcing flat profile, libinput applies
# its own acceleration on top of YeetMouse's custom curve, making the mouse
# feel faster than Windows with identical Raw Accel settings.
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.myModules.hardware.yeetmouse.devices.g502;
in
{
  options.myModules.hardware.yeetmouse.devices.g502 = {
    enable = mkEnableOption "Libinput flat acceleration profile for Logitech G502 (Wired/Wireless)";

    wiredProductId = mkOption {
      type = types.str;
      default = "c08d";
      description = "USB product ID for the wired G502 (check with lsusb)";
    };

    wirelessProductId = mkOption {
      type = types.str;
      default = "c539";
      description = "USB product ID for the Lightspeed Receiver";
    };

    dpi = mkOption {
      type = types.int;
      default = 1600;
      description = "Mouse DPI setting (reported to libinput via HWDB)";
    };

    pollingRate = mkOption {
      type = types.int;
      default = 1000;
      description = "Mouse polling rate in Hz (reported to libinput via HWDB)";
    };
  };

  config = mkIf cfg.enable {
    # Force flat acceleration profile via libinput HWDB
    # This prevents libinput from applying additional acceleration
    # on top of YeetMouse's custom acceleration curve.
    services.udev.extraHwdb = ''
      # Logitech G502 Lightspeed Receiver
      evdev:input:b0003v046Dp${toUpper cfg.wirelessProductId}*
       MOUSE_DPI=${toString cfg.dpi}@${toString cfg.pollingRate}
       ID_INPUT_MOUSE_ACCEL_PROFILE=flat

      # Logitech G502 Wired
      evdev:input:b0003v046Dp${toUpper cfg.wiredProductId}*
       MOUSE_DPI=${toString cfg.dpi}@${toString cfg.pollingRate}
       ID_INPUT_MOUSE_ACCEL_PROFILE=flat

      # Kernel-exposed input device ID (0x407F)
      evdev:input:b0003v046Dp407F*
       MOUSE_DPI=${toString cfg.dpi}@${toString cfg.pollingRate}
       ID_INPUT_MOUSE_ACCEL_PROFILE=flat

      # Generic fallback by name for any G502 variant
      evdev:name:Logitech G502*
       MOUSE_DPI=${toString cfg.dpi}@${toString cfg.pollingRate}
       ID_INPUT_MOUSE_ACCEL_PROFILE=flat
    '';

    # Ensure yeetmouse kernel module is loaded at boot
    boot.kernelModules = [ "yeetmouse" ];
  };
}

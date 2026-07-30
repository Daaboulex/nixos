# udev-access — USB device access rules for development hardware (plugdev group).
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
      cfg = config.myModules.hardware.udevAccess;
    in
    {
      _class = "nixos";
      options.myModules.hardware.udevAccess = {
        enable = lib.mkEnableOption "USB device access rules for development hardware";
        saleae = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Saleae Logic analyzer udev rules";
        };
        debuggingProbes = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Embedded debugging probes (LPC-Link2, ESP32) udev rules";
        };
      };
      config = lib.mkIf cfg.enable {
        services.udev.packages = lib.optionals cfg.saleae [
          pkgs.saleae-logic-2
        ];
        services.udev.extraRules = lib.optionalString cfg.debuggingProbes ''
          # LPC-Link2 debug probe — DFU bootloader mode
          ATTRS{idVendor}=="1fc9", ATTRS{idProduct}=="000c", MODE="0660", GROUP="dialout"
          # LPC-Link2 debug probe — CMSIS-DAP interface
          ATTRS{idVendor}=="1fc9", ATTRS{idProduct}=="0090", MODE="0660", GROUP="dialout"
          # LPC-Link2 debug probe — LPCXpresso/LinkServer interface
          ATTRS{idVendor}=="1fc9", ATTRS{idProduct}=="0143", MODE="0660", GROUP="dialout"
          # ESP32-S3 USB-to-serial (Espressif JTAG/serial)
          ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", MODE="0660", GROUP="dialout"
        '';
      };
    };
in
{
  flake.modules.nixos.hardware-udev-access = mod;

}

# usb-power — disable USB autosuspend to prevent WiFi dropouts on USB wireless adapters.
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
      cfg = config.myModules.hardware.usbPower;
    in
    {
      _class = "nixos";

      options.myModules.hardware.usbPower = {
        enable = lib.mkEnableOption "USB device power management fix (prevents WiFi drops)";
        vendorId = lib.mkOption {
          type = lib.types.str;
          default = "0bda";
          description = "USB vendor ID to disable power management for (default: Realtek).";
        };
      };

      config = lib.mkIf cfg.enable {
        services.udev.extraRules = ''
          ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="${cfg.vendorId}", TEST=="power/control", ATTR{power/control}="on"
        '';
      };
    };
in
{
  flake.modules.nixos.hardware-usb-power = mod;

}

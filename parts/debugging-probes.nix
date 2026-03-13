{ inputs, ... }:
{
  flake.nixosModules.development-debugging-probes =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.development.debuggingProbes;
    in
    {
      _class = "nixos";
      options.myModules.development.debuggingProbes = {
        enable = lib.mkEnableOption "Embedded debugging probes (LPC-Link2, ESP32) udev rules";
      };

      config = lib.mkIf cfg.enable {
        services.udev.extraRules = ''
          # LPC-Link2 debug probe — CMSIS-DAP interface
          ATTRS{idVendor}=="1fc9", ATTRS{idProduct}=="0090", MODE="0666", GROUP="dialout"
          # LPC-Link2 debug probe — LPCXpresso/LinkServer interface
          ATTRS{idVendor}=="1fc9", ATTRS{idProduct}=="0143", MODE="0666", GROUP="dialout"
          # ESP32-S3 USB-to-serial (Espressif JTAG/serial)
          ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", MODE="0666", GROUP="dialout"
        '';
      };
    };
}

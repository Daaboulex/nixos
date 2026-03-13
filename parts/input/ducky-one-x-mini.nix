{ inputs, ... }:
{
  flake.nixosModules.input-ducky-one-x-mini =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.input.duckyOneXMini;
    in
    {
      _class = "nixos";
      options.myModules.input.duckyOneXMini = {
        enable = lib.mkEnableOption "Ducky One X Mini keyboard HID access (udev rules for VIA/Vial)";

        vendor = lib.mkOption {
          type = lib.types.str;
          default = "3233";
          description = "USB vendor ID for the Ducky keyboard";
        };

        board.product = lib.mkOption {
          type = lib.types.str;
          default = "001d";
          description = "USB product ID for the keyboard board HID interface";
        };

        mcu.product = lib.mkOption {
          type = lib.types.str;
          default = "0021";
          description = "USB product ID for the keyboard MCU HID interface";
        };
      };

      config = lib.mkIf cfg.enable {
        services.udev.extraRules = ''
          # Ducky One X Mini — Board HID
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="${cfg.vendor}", ATTRS{idProduct}=="${cfg.board.product}", MODE="0666"
          # Ducky One X Mini — MCU HID
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="${cfg.vendor}", ATTRS{idProduct}=="${cfg.mcu.product}", MODE="0666"
        '';
      };
    };
}

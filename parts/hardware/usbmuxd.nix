# usbmuxd — USB multiplexing daemon for iOS device support (iPhone/iPad tethering).
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
      cfg = config.myModules.hardware.usbmuxd;
    in
    {
      _class = "nixos";
      options.myModules.hardware.usbmuxd = {
        enable = lib.mkEnableOption "USB multiplexing daemon (iOS device support)";
      };

      config = lib.mkIf cfg.enable {
        services.usbmuxd.enable = true;

      };
    };
in
{
  flake.modules.nixos.hardware-usbmuxd = mod;

}

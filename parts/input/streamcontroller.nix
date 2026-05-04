# streamcontroller — StreamController (Elgato Stream Deck) support with udev rules.
_:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.input.streamcontroller;
    in
    {
      _class = "nixos";
      options.myModules.input.streamcontroller = {
        enable = lib.mkEnableOption "StreamController (Elgato Stream Deck)";
      };

      config = lib.mkIf cfg.enable {
        # Elgato Stream Deck USB device access (vendor 0x0fd9)
        services.udev.packages = [ pkgs.streamcontroller ];
      };
    };
in
{
  flake.modules.nixos.input-streamcontroller = mod;

}

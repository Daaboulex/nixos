# goxlr — GoXLR Mini audio mixer support (goxlr-utility daemon and udev).
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.myModules.hardware.goxlr;
    in
    {
      _class = "nixos";
      options.myModules.hardware.goxlr = {
        enable = lib.mkEnableOption "GoXLR Mini support";
        utility.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "goxlr-utility daemon";
        };
      };

      config = lib.mkIf cfg.enable {
        services.goxlr-utility = lib.mkIf cfg.utility.enable {
          enable = true;
          autoStart.xdg = true;
        };

        # Raw GoXLR ALSA nodes can't be hidden from the Plasma volume applet
        # under PipeWire's current permission model: the EQ filter chains target
        # raw UCM sinks by node.name, and any permission denial that hides them
        # from pipewire-pulse also breaks the audio graph.
      };
    };
in
{
  flake.modules.nixos.hardware-goxlr = mod;
}

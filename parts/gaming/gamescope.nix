# gamescope — Gamescope micro-compositor for gaming (HDR, VRR, upscaling).
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.myModules.gaming.gamescope;
    in
    {
      _class = "nixos";
      options.myModules.gaming.gamescope = {
        enable = lib.mkEnableOption "Gamescope compositor";
      };
      config = lib.mkIf cfg.enable {
        programs.gamescope.enable = true;
      };
    };
in
{
  flake.modules.nixos.gaming-gamescope = mod;

}

# gamescope — Valve's micro-compositor for gaming.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.gamescope;
in
{
  options.myModules.home.gamescope = {
    enable = lib.mkEnableOption "Gamescope compositor";
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.gamescope ];

    home.sessionVariables = {
      GAMESCOPE_LIMITER_FILE = lib.mkDefault "/tmp/gamescope-limiter";
    };
  };
}

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

    # Per-user runtime path (not a shared /tmp file) so two concurrent sessions —
    # e.g. a multiseat host with two logged-in users — never clobber one limiter.
    home.sessionVariables = {
      GAMESCOPE_LIMITER_FILE = lib.mkDefault "\${XDG_RUNTIME_DIR}/gamescope-limiter";
    };
  };
}

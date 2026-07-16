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
    # session-vars-ok: the value uses runtime ${XDG_RUNTIME_DIR}, which the login
    # shell and environment.d(5) expand differently, so this stays login-shell
    # scoped rather than going through mkSessionVars (GUI launches inherit
    # XDG_RUNTIME_DIR from the session regardless).
    home.sessionVariables = {
      GAMESCOPE_LIMITER_FILE = lib.mkDefault "\${XDG_RUNTIME_DIR}/gamescope-limiter";
    };
  };
}

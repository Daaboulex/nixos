# kiro — FHS-wrapped Kiro IDE with optional CLI companion.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.kiro;
in
{
  options.myModules.home.kiro = {
    enable = lib.mkEnableOption "Kiro IDE (FHS-wrapped)";
    cli = lib.mkEnableOption "Kiro CLI";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.kiro-fhs ] ++ lib.optionals cfg.cli [ pkgs.kiro-cli ];
  };
}

# elisa — KDE music player.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.elisa;
in
{
  options.myModules.home.elisa.enable = lib.mkEnableOption "Elisa KDE music player";

  config = lib.mkIf cfg.enable {
    programs.elisa.enable = true;
  };
}

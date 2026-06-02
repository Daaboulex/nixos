# xdg — XDG user directory configuration (Downloads, Documents, etc.).
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.xdg;
in
{
  options.myModules.home.xdg = {
    enable = lib.mkEnableOption "XDG user directories";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    # ============================================================================
    # XDG User Directories
    # ============================================================================
    xdg = myLib.mergeSettings {
      defaults = {
        enable = lib.mkDefault true;
        userDirs = {
          enable = lib.mkDefault true;
          createDirectories = lib.mkDefault true;
          desktop = lib.mkDefault "${config.home.homeDirectory}/Desktop";
          documents = lib.mkDefault "${config.home.homeDirectory}/Documents";
          download = lib.mkDefault "${config.home.homeDirectory}/Downloads";
          music = lib.mkDefault "${config.home.homeDirectory}/Music";
          pictures = lib.mkDefault "${config.home.homeDirectory}/Pictures";
          publicShare = lib.mkDefault "${config.home.homeDirectory}/Public";
          templates = lib.mkDefault "${config.home.homeDirectory}/Templates";
          videos = lib.mkDefault "${config.home.homeDirectory}/Videos";
        };
      };
      overrides = cfg.settings;
    };
  };
}

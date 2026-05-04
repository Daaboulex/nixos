# okular — KDE PDF viewer.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:

let
  cfg = config.myModules.home.okular;
in
{
  options.myModules.home.okular = {
    enable = lib.mkEnableOption "Okular KDE PDF viewer";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    # ============================================================================
    # Okular (PDF Viewer) — native plasma-manager options where available
    # ============================================================================
    programs.okular = myLib.mergeSettings {
      defaults = {
        enable = true;
        accessibility.changeColors.enable = lib.mkDefault false;
      };
      overrides = cfg.settings;
    };

    # ============================================================================
    # Okular configFile — settings without native plasma-manager options
    # ============================================================================
    programs.plasma.configFile = {
      "okularpartrc"."Main View" = {
        ShowLeftPanel = lib.mkDefault false; # Maximise reading area
      };

      "okularrc"."General" = {
        LockSidebar = lib.mkDefault true;
        ShowSidebar = lib.mkDefault true;
      };
    };
  };
}

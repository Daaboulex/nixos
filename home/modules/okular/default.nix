{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Okular (PDF Viewer) — native plasma-manager options where available
  # ============================================================================
  programs.okular = {
    enable = true;
    accessibility.changeColors.enable = lib.mkDefault false;
  };

  # ============================================================================
  # Okular configFile — settings without native plasma-manager options
  # ============================================================================
  programs.plasma.configFile = {
    "okularpartrc"."Main View" = {
      ShowLeftPanel = lib.mkDefault false;            # Maximise reading area
    };

    "okularrc"."General" = {
      LockSidebar = lib.mkDefault true;
      ShowSidebar = lib.mkDefault true;
    };
  };
}

{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Okular (PDF Viewer)
  # ============================================================================
  programs.okular = {
    enable = true;
    # package = pkgs.kdePackages.okular;
    # general = {
    #   openFileInTabs = true;
    #   showScrollbars = true;
    #   smoothScrolling = true;
    #   viewContinuous = true;
    #   viewMode = "Single";  # "Single", "Facing", "FacingFirstCentered", "Summary"
    #   zoomMode = "fitWidth";  # "100%", "fitWidth", "fitPage", "autoFit"
    # };
  };

  # ============================================================================
  # Okular configFile — settings without native plasma-manager options
  # ============================================================================
  programs.plasma.configFile = {
    "okularpartrc"."Document" = {
      ChangeColors = lib.mkDefault false;             # Don't alter document colors
    };

    "okularpartrc"."Main View" = {
      ShowLeftPanel = lib.mkDefault false;            # Maximise reading area
    };

    "okularrc"."General" = {
      LockSidebar = lib.mkDefault true;
      ShowSidebar = lib.mkDefault true;
    };
  };
}

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
}

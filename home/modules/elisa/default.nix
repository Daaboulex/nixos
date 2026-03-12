{
  config,
  pkgs,
  lib,
  ...
}:

{
  # ============================================================================
  # Elisa (Music Player) - Disabled
  # ============================================================================
  programs.elisa = {
    enable = false;
    # package = pkgs.kdePackages.elisa;
    # appearance = {
    #   defaultView = "allAlbums";
    #   showNowPlayingBackground = true;
    # };
    # indexer = {
    #   scanAtStartup = true;
    #   paths = [ "$HOME/Music" ];
    # };
    # player = {
    #   minimiseToSystemTray = false;
    # };
  };
}

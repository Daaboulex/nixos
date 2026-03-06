{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Kate (Text Editor)
  # ============================================================================
  programs.kate = {
    enable = true;
    # package = pkgs.kdePackages.kate;
    # editor = {
    #   font = {
    #     family = "JetBrainsMono Nerd Font";
    #     pointSize = 11;
    #   };
    #   indent = {
    #     width = 2;
    #     replaceWithSpaces = true;
    #     showLines = true;
    #   };
    #   tabWidth = 2;
    #   inputMode = "normal";  # or "vi"
    #   brackets = {
    #     automaticallyAddClosing = true;
    #     highlightMatching = true;
    #   };
    # };
    # lsp.customServers = null;
    # dap.customServers = null;
  };
}

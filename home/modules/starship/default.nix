{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Starship Prompt - Modern shell prompt
  # ============================================================================
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = lib.mkDefault true;

      # Classic "user@host" format with modern styling
      username = {
        show_always = lib.mkDefault true;
        style_user = lib.mkDefault "bold blue";
        format = lib.mkDefault "[$user]($style)@";
      };

      hostname = {
        ssh_only = lib.mkDefault false;
        style = lib.mkDefault "bold blue";
        format = lib.mkDefault "[$hostname]($style) ";
      };
    };
  };
}

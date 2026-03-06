{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Starship Prompt - Modern shell prompt
  # ============================================================================
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = true;

      # Classic "user@host" format with modern styling
      username = {
        show_always = true;
        style_user = "bold blue";
        format = "[$user]($style)@";
      };

      hostname = {
        ssh_only = false;
        style = "bold blue";
        format = "[$hostname]($style) ";
      };
    };
  };
}

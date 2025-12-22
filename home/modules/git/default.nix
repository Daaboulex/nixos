{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Git Configuration
  # ============================================================================
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "stephandaaboul";
        email = "s.daaboul@jacobs-university.de";
      };
    };
  };

  # ============================================================================
  # GitHub CLI
  # ============================================================================
  programs.gh = {
    enable = true;
    gitCredentialHelper = {
      enable = true;
    };
  };
}

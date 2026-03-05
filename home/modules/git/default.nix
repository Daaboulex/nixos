{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Git Configuration
  # ============================================================================
  programs.git = {
    enable = true;
    # User credentials set per-host in home/hosts/<hostname>/default.nix
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

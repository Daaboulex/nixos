{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # direnv — Per-directory environments (auto-loads .envrc / shell.nix)
  # ============================================================================
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
}

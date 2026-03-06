{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Zoxide — Smarter cd (learns frequent directories, use `z` instead of `cd`)
  # ============================================================================
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}

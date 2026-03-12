{
  config,
  pkgs,
  lib,
  ...
}:

{
  # ============================================================================
  # fzf — Fuzzy finder (Ctrl+R history, Ctrl+T files, Alt+C directories)
  # ============================================================================
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}

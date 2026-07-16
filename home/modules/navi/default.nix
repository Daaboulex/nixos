# navi — interactive fzf-backed command cheatsheets (Ctrl-G widget).
{
  config,
  lib,
  ...
}:
let
  cfg = config.myModules.home.navi;
in
{
  options.myModules.home.navi.enable = lib.mkEnableOption "navi interactive command cheatsheets";

  config = lib.mkIf cfg.enable {
    programs.navi = {
      enable = true;
      enableZshIntegration = true; # Ctrl-G widget injected by HM (same mechanism as fzf/atuin/zoxide)
    }
    # finder reuses fzf only when fzf is enabled (guarded cross-module ref, AUDIT.md §19)
    // lib.optionalAttrs config.myModules.home.fzf.enable {
      settings.finder.command = "fzf";
    };
  };
}

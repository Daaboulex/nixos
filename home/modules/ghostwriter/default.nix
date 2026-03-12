{
  config,
  pkgs,
  lib,
  ...
}:

{
  # ============================================================================
  # Ghostwriter (Markdown Editor) - Disabled
  # ============================================================================
  programs.ghostwriter = {
    enable = false;
    # package = pkgs.kdePackages.ghostwriter;
    # editor = {
    #   styling = {
    #     focusMode = "sentence";
    #     editorWidth = "medium";
    #     useLargeHeadings = true;
    #   };
    # };
    # general = {
    #   fileSaving.autoSave = true;
    #   session.rememberRecentFiles = true;
    # };
    # spelling = {
    #   liveSpellCheck = true;
    #   checkerEnabledByDefault = true;
    # };
  };
}

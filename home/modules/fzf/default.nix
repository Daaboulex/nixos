# fzf — fuzzy finder with ripgrep/fd integration and theme-derived colors.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.fzf;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;
  # Use ripgrep for file listing (fast, respects .gitignore)
  rgCmd = "${pkgs.ripgrep}/bin/rg --files --hidden --glob '!.git'";
  # Use fd for directory listing
  fdCmd = "${pkgs.fd}/bin/fd --type d --hidden --exclude .git";
  # bat preview for files, eza tree for directories
  previewCmd = "${pkgs.bat}/bin/bat --color=always --style=numbers --line-range=:200 {}";
  dirPreviewCmd = "${pkgs.eza}/bin/eza --tree --color=always --icons --level=2 {}";
in
{
  options.myModules.home.fzf = {
    enable = lib.mkEnableOption "fzf fuzzy finder";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    programs.fzf = myLib.mergeSettings {
      defaults = {
        enable = true;
        enableZshIntegration = lib.mkDefault true;

        # Use ripgrep for default file listing (respects .gitignore, fast)
        defaultCommand = lib.mkDefault rgCmd;

        # Ctrl+T: file picker with bat syntax preview
        fileWidget.command = lib.mkDefault rgCmd;
        fileWidget.options = lib.mkDefault [
          "--preview '${previewCmd}'"
          "--preview-window=right:50%:wrap"
        ];

        # Alt+C: directory picker with eza tree preview
        changeDirWidget.command = lib.mkDefault fdCmd;
        changeDirWidget.options = lib.mkDefault [
          "--preview '${dirPreviewCmd}'"
          "--preview-window=right:50%"
        ];

        # Ctrl+R: history search with timestamps
        historyWidget.options = lib.mkDefault [
          "--layout=reverse"
        ];
        # Atuin owns Ctrl-R when enabled — an empty command drops fzf's binding
        historyWidget.command = lib.mkIf config.myModules.home.atuin.enable (lib.mkDefault "");
      }
      // lib.optionalAttrs hasTheme {
        colors = {
          "bg" = c.background;
          "bg+" = c.surface;
          "fg" = c.foreground;
          "fg+" = c.foreground;
          "hl" = c.blue;
          "hl+" = c.blue;
          "info" = c.orange;
          "prompt" = c.blue;
          "pointer" = c.blue;
          "marker" = c.green;
          "spinner" = c.blue;
          "header" = c.foreground-dim;
          "border" = c.foreground-dim;
          "preview-bg" = c.background-alt;
        };
      };
      overrides = cfg.settings;
    };
  };
}

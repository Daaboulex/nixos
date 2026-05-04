# zellij — terminal workspace/multiplexer with theme-derived colors.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.zellij;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;
in
{
  options.myModules.home.zellij = {
    enable = lib.mkEnableOption "Zellij terminal workspace (multiplexer)";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    programs.zellij = myLib.mergeSettings {
      defaults = {
        enable = true;
        enableZshIntegration = lib.mkDefault false;
        settings = {
          default_layout = "compact";
          pane_frames = false;
          simplified_ui = false;
          mouse_mode = true;
          copy_on_select = true;
          scrollback_editor = "nvim";
        }
        // lib.optionalAttrs hasTheme {
          theme = "breeze-dark";
          themes.breeze-dark = {
            fg = c.foreground;
            bg = c.background;
            black = c.background;
            inherit (c) red;
            inherit (c) green;
            yellow = c.orange;
            inherit (c) blue;
            magenta = c.purple;
            cyan = c.blue-alt;
            white = c.foreground;
            inherit (c) orange;
          };
        };
      };
      overrides = cfg.settings;
    };
  };
}

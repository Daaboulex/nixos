# tealdeer — tldr command cheatsheets with theme-derived colors.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.tealdeer;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;
in
{
  options.myModules.home.tealdeer.enable = lib.mkEnableOption "tealdeer (tldr) command cheatsheets";

  config = lib.mkIf cfg.enable {
    programs.tealdeer = {
      enable = true;
      settings = {
        updates.auto_update = lib.mkDefault true;
      }
      // lib.optionalAttrs hasTheme {
        style = {
          description.foreground = myLib.cap c.foreground-dim-ansi;
          command_name = {
            foreground = myLib.cap c.blue-ansi;
            bold = true;
          };
          example_text.foreground = myLib.cap c.foreground-dim-ansi;
          example_code = {
            foreground = myLib.cap c.blue-alt-ansi;
            bold = true;
          };
          example_variable = {
            foreground = myLib.cap c.orange-ansi;
            underline = true;
          };
        };
      };
    };
  };
}

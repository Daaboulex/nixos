# csvlens — terminal CSV viewer with theme-derived color palette.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.csvlens;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;
in
{
  options.myModules.home.csvlens.enable = lib.mkEnableOption "csvlens CSV file viewer";
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.csvlens ];

    xdg.configFile."csvlens/config.ini" = lib.mkIf hasTheme {
      text = ''
        [csvlens]
        header_color = ${myLib.cap c.blue-ansi}
        selection_color = ${myLib.cap c.blue-alt-ansi}
      '';
    };
  };
}

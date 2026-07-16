# glow — terminal markdown renderer with theme integration.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.glow;
  inherit (myLib.themeCtx { inherit config; }) hasTheme;
in
{
  options.myModules.home.glow = {
    enable = lib.mkEnableOption "glow terminal markdown renderer";
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra lines appended to glow.yml.";
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.glow ];

    xdg.configFile."glow/glow.yml" = lib.mkIf hasTheme {
      text = ''
        style: "dark"
        pager: true
        width: 120
      ''
      + lib.optionalString (cfg.extraConfig != "") "\n${cfg.extraConfig}\n";
    };
  };
}

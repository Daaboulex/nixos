# jq — command-line JSON processor with theme-derived JQ_COLORS.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.jq;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;

  # JQ_COLORS format: colon-separated ANSI SGR codes for:
  # null:false:true:number:string:array:object:key
  ansiCode =
    name:
    {
      "blue" = "0;34";
      "red" = "0;31";
      "green" = "0;32";
      "yellow" = "0;33";
      "magenta" = "0;35";
      "cyan" = "0;36";
      "white" = "0;37";
      "black" = "0;90";
    }
    .${name} or "0";
in
{
  options.myModules.home.jq.enable = lib.mkEnableOption "jq command-line JSON processor";

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { programs.jq.enable = true; }
      # Theme-derived JSON syntax colors
      (myLib.mkSessionVars (
        lib.mkIf hasTheme {
          JQ_COLORS = lib.concatStringsSep ":" [
            (ansiCode c.foreground-dim-ansi) # null
            (ansiCode c.red-ansi) # false
            (ansiCode c.green-ansi) # true
            (ansiCode c.orange-ansi) # number
            (ansiCode c.green-ansi) # string
            (ansiCode c.foreground-dim-ansi) # array brackets
            (ansiCode c.foreground-dim-ansi) # object braces
            "1;${ansiCode c.blue-ansi}" # key (bold)
          ];
        }
      ))
    ]
  );
}

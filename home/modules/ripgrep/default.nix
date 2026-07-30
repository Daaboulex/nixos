# ripgrep — fast recursive search with theme-derived colors.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.ripgrep;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;
in
{
  options.myModules.home.ripgrep.enable = lib.mkEnableOption "ripgrep fast recursive search";
  config = lib.mkIf cfg.enable {
    programs.ripgrep = {
      enable = lib.mkDefault true;
      package = lib.mkDefault pkgs.ripgrep-nix;
      arguments = lib.mkDefault (
        [
          "--smart-case"
          "--hidden"
          "--glob=!.git"
        ]
        ++ lib.optionals hasTheme [
          "--colors=path:fg:${c.green-ansi}"
          "--colors=line:fg:${c.orange-ansi}"
          "--colors=match:fg:${c.blue-ansi}"
          "--colors=match:style:bold"
        ]
      );
    };
  };
}

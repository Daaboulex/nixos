# bat — syntax-highlighted cat replacement with theme integration and MANPAGER hookup.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.bat;
  inherit (myLib.themeCtx { inherit config; }) hasTheme;
in
{
  options.myModules.home.bat.enable = lib.mkEnableOption "bat syntax-highlighted cat replacement";

  config = lib.mkIf cfg.enable {
    programs.bat = {
      enable = true;
      config = lib.mkIf hasTheme {
        theme = "base16";
      };
    };

    # Colored man pages via bat
    home.sessionVariables = {
      MANPAGER = lib.mkDefault "sh -c 'col -bx | bat -l man -p'";
      MANROFFOPT = lib.mkDefault "-c";
    };
  };
}

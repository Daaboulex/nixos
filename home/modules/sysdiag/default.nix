# sysdiag — system diagnostics helper script with theme-aware output.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.sysdiag;
  inherit (myLib.themeCtx { inherit config; }) hasTheme theme;
  scriptText = import ./sysdiag-script.nix {
    inherit pkgs;
    colors = if hasTheme then theme.colors else null;
  };
  sysdiag = pkgs.writeShellScriptBin "sysdiag" scriptText;
in
{
  options.myModules.home.sysdiag = {
    enable = lib.mkEnableOption "sysdiag system diagnostics script";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ sysdiag ];
  };
}

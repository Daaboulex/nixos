# sysstat — sar/iostat/pidstat performance monitoring toolkit.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.sysstat;
in
{
  options.myModules.home.sysstat.enable = lib.mkEnableOption "sysstat (sar/iostat/pidstat)";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.sysstat ];
  };
}

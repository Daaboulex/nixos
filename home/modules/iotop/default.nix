# iotop — per-process disk I/O monitor (iotop-c: colorised modern fork).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.iotop;
in
{
  options.myModules.home.iotop.enable = lib.mkEnableOption "iotop-c disk I/O monitor";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.iotop-c ];
  };
}

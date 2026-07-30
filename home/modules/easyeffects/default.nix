# easyeffects — PipeWire audio effects processor (EQ, compressor, noise suppression).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.easyeffects;
in
{
  options.myModules.home.easyeffects.enable =
    lib.mkEnableOption "EasyEffects audio effects processor";

  config = lib.mkIf cfg.enable {
    services.easyeffects.enable = lib.mkDefault true;
  };
}

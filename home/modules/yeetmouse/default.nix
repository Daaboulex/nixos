# yeetmouse — YeetMouse configuration GUI (requires NixOS yeetmouse driver).
{
  config,
  lib,
  pkgs,
  options,
  osConfig ? { },
  ...
}:
let
  cfg = config.myModules.home.yeetmouse;
  hasDriver = osConfig.hardware.yeetmouse.enable or false;
  hasHmModule = options ? programs && options.programs ? yeetmouse;
in
{
  options.myModules.home.yeetmouse.enable =
    lib.mkEnableOption "YeetMouse GUI (requires NixOS yeetmouse driver)";

  config = lib.mkIf (cfg.enable && hasDriver) (
    lib.optionalAttrs hasHmModule {
      programs.yeetmouse.enable = true;
    }
  );
}

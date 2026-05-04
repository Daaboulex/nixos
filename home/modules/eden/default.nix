# eden — Eden Switch emulator.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.eden;
in
{
  options.myModules.home.eden = {
    enable = lib.mkEnableOption "Eden Switch emulator";
  };
  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.eden
    ];
  };
}

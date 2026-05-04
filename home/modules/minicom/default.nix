# minicom — serial terminal emulator.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.minicom;
in
{
  options.myModules.home.minicom = {
    enable = lib.mkEnableOption "minicom serial terminal";
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Full text content of `~/.minirc.dfl`. There is no base config —
        the value here becomes the entire file. Setting an empty string
        leaves no `.minirc.dfl` written at all.
        Example lines: `pu port /dev/ttyUSB0`, `pu baudrate 115200`,
        `pu rtscts No`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      minicom
    ];

    home.file.".minirc.dfl" = lib.mkIf (cfg.extraConfig != "") {
      text = cfg.extraConfig;
    };
  };
}

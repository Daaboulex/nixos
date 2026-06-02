# wget — HTTP download client with user .wgetrc configuration.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.wget;
in
{
  options.myModules.home.wget = {
    enable = lib.mkEnableOption "wget HTTP client";
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Full text content of `~/.wgetrc`. There is no base config — the
        value here becomes the entire file. Setting an empty string
        leaves no `.wgetrc` written at all.
        Example lines: `tries = 3`, `timeout = 30`, `timestamping = on`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      wget
    ];

    home.file.".wgetrc" = lib.mkIf (cfg.extraConfig != "") {
      text = cfg.extraConfig;
    };
  };
}

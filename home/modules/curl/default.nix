# curl — HTTP client with user .curlrc configuration.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.curl;
in
{
  options.myModules.home.curl = {
    enable = lib.mkEnableOption "curl HTTP client";
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Full text content of `~/.curlrc`. There is no base config — the
        value here becomes the entire file. Setting an empty string
        leaves no `.curlrc` written at all.
        Example lines: `--compressed`, `--location`, `--max-time 30`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      curl
    ];

    home.file.".curlrc" = lib.mkIf (cfg.extraConfig != "") {
      text = cfg.extraConfig;
    };
  };
}

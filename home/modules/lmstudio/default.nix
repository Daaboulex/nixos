# lmstudio — LM Studio desktop app (stable/beta channel) with optional user daemon.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.lmstudio;
  packageForChannel = {
    "stable" = pkgs.lmstudio;
    "beta" = pkgs.lmstudio-beta;
  };
in
{
  options.myModules.home.lmstudio = {
    enable = lib.mkEnableOption "LM Studio desktop app";

    channel = lib.mkOption {
      type = lib.types.enum [
        "stable"
        "beta"
      ];
      default = "stable";
      description = "LM Studio release channel (stable or beta).";
    };

    server = {
      enable = lib.mkEnableOption "LM Studio user daemon";
      port = lib.mkOption {
        type = lib.types.port;
        default = 1234;
        description = "Port for LM Studio API server.";
      };
      autostart = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Start LM Studio daemon on login.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.lmstudio = {
      enable = true;
      package = packageForChannel.${cfg.channel};
      server = {
        inherit (cfg.server) enable port autostart;
      };
    };
  };
}

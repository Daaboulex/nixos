# openviking — OpenViking context database with configurable read-only search paths.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.openviking;
in
{
  options.myModules.home.openviking = {
    enable = lib.mkEnableOption "OpenViking context database";
    readOnlyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Paths to index as read-only in OpenViking.";
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.openviking ];
    systemd.user.services.openviking = {
      Unit = {
        Description = "OpenViking context database";
        After = [ "default.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart =
          "${pkgs.openviking}/bin/openviking serve --data-dir %h/.local/share/openviking"
          + lib.concatMapStrings (p: " --read-only-path ${p}") cfg.readOnlyPaths;
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}

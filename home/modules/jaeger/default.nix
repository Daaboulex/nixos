# jaeger — Jaeger all-in-one tracing backend (OTLP gRPC/HTTP + query UI) as user service.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.jaeger;
in
{
  options.myModules.home.jaeger = {
    enable = lib.mkEnableOption "Jaeger all-in-one tracing backend";

    otlpGrpcPort = lib.mkOption {
      type = lib.types.port;
      default = 4317;
      description = "OTLP gRPC receiver port.";
    };

    otlpHttpPort = lib.mkOption {
      type = lib.types.port;
      default = 4318;
      description = "OTLP HTTP receiver port.";
    };

    queryPort = lib.mkOption {
      type = lib.types.port;
      default = 16686;
      description = "Jaeger UI query port (browse at http://localhost:16686).";
    };

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Jaeger on login.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.jaeger ];

    systemd.user.services.jaeger = {
      Unit = {
        Description = "Jaeger all-in-one tracing backend";
        After = [ "network.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.jaeger}/bin/jaeger-all-in-one"
          "--collector.otlp.grpc.host-port=:${toString cfg.otlpGrpcPort}"
          "--collector.otlp.http.host-port=:${toString cfg.otlpHttpPort}"
          "--query.http-server.host-port=:${toString cfg.queryPort}"
        ];
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install = lib.mkIf cfg.autostart {
        WantedBy = [ "default.target" ];
      };
    };
  };
}

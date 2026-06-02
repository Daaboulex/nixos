# tidalcycles — TidalCycles live-coding environment with optional SuperDirt autostart.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.home.tidalcycles;
in
{
  options.myModules.home.tidalcycles = {
    enable = lib.mkEnableOption "TidalCycles live coding";
    superdirt = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include SuperDirt (SuperCollider audio engine)";
    };
    autostartSuperDirt = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Auto-start SuperDirt (SuperCollider) as a systemd user service";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.tidal
    ]
    ++ lib.optionals cfg.superdirt [
      pkgs.superdirt-start
      pkgs.superdirt-install
    ];

    systemd.user.services.superdirt-start = lib.mkIf (cfg.superdirt && cfg.autostartSuperDirt) {
      Unit = {
        Description = "Start SuperDirt (SuperCollider)";
        After = [ "default.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.superdirt-start}/bin/superdirt-start";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}

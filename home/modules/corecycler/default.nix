# corecycler — per-core CPU stability tester and PBO Curve Optimizer tuner.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.corecycler;
  package = if cfg.unfreeBackends then pkgs.linux-corecycler-full else pkgs.linux-corecycler;
in
{
  options.myModules.home.corecycler = {
    enable = lib.mkEnableOption "CoreCyclerLx per-core CPU stability tester and PBO Curve Optimizer tuner";
    unfreeBackends = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to include unfree backends (mprime). When false, only FOSS backends (stress-ng) are bundled.";
    };
    autoResume = {
      enable = lib.mkEnableOption "resuming the active tuner session automatically after login. Only mid-run sessions qualify (a paused session is a deliberate choice; quarantined never resumes); the app also enforces a single-instance lock. Runs sudo-less via the corecycler device-access group.";
      delaySeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 120;
        description = "Settle time after login before the session resumes.";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ package ];

    xdg.configFile."autostart/corecycler-autoresume.desktop" = lib.mkIf cfg.autoResume.enable {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=CoreCycler auto-resume
        Exec=${lib.getExe package} --auto-resume ${toString cfg.autoResume.delaySeconds}
        X-GNOME-Autostart-enabled=true
      '';
    };
  };
}

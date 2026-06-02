# power — Plasma Powerdevil and KScreenLocker settings.
{
  config,
  lib,
  myLib,
  ...
}:

let
  cfg = config.myModules.home.plasma.power;
in
{
  options.myModules.home.plasma.power = {
    enable = lib.mkEnableOption "Plasma power management and screen locker";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    programs.plasma = myLib.mergeSettings {
      defaults = {
        # ==========================================================================
        # KScreenLocker — idle lock + wake lock
        # ==========================================================================
        kscreenlocker = {
          autoLock = lib.mkDefault true;
          timeout = lib.mkDefault 10; # Lock after 10 minutes idle
          lockOnResume = lib.mkDefault true; # Lock on wake from sleep
          passwordRequired = lib.mkDefault true;
          passwordRequiredDelay = lib.mkDefault 0; # Require password immediately
        };

        # ==========================================================================
        # Power Management — dim / DPMS off (CRT phosphor protection)
        # ==========================================================================
        powerdevil = {
          AC = {
            autoSuspend.action = lib.mkDefault "nothing"; # Desktop — never auto-suspend
            dimDisplay = {
              enable = lib.mkDefault true;
              idleTimeout = lib.mkDefault 300; # Dim after 5 minutes
            };
            turnOffDisplay = {
              idleTimeout = lib.mkDefault 600; # DPMS off after 10 minutes
            };
            powerProfile = lib.mkDefault "balanced";
            powerButtonAction = lib.mkDefault "showLogoutScreen"; # Trigger KDE logout dialog (saves session)
          };
        };
      };
      overrides = cfg.settings;
    };
  };
}

# power — optional TLP (battery/AC CPU/platform/wifi profiles) + power-profiles-daemon disabled.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.hardware.power;
    in
    {
      _class = "nixos";
      options.myModules.hardware.power = {
        enable = lib.mkEnableOption "Power management configuration";
        # TLP power management — a capability (enable if you want TLP), NOT a
        # host-class label. Battery/AC-oriented, so typically laptops, but the
        # toggle names the tool, not the machine: a power-conscious desktop
        # could opt in too.
        tlp = lib.mkEnableOption "TLP power management (battery charge thresholds + AC/BAT CPU/platform/wifi profiles)";
        # power-profiles-daemon -- the KDE/GNOME power-profile selector backend.
        # Also a capability toggle, not a host label. Mutually exclusive with tlp.
        powerProfilesDaemon = lib.mkEnableOption "power-profiles-daemon (KDE/GNOME power-profile switching; sets EPP on amd-pstate-epp)";
      };

      config = lib.mkIf cfg.enable {
        # power-profiles-daemon: opt-in (default off). On amd-pstate-epp it sets the
        # EPP hint and is consumed -- not fought -- by scx_lavd, so it composes with
        # the governor and scheduler. NOT compatible with TLP (both manage power) --
        # mutually exclusive, asserted below.
        # Why: nixpkgs desktop profiles default this on; mkForce makes this option
        # (cfg.powerProfilesDaemon) the single source of truth.
        services.power-profiles-daemon.enable = lib.mkForce cfg.powerProfilesDaemon;

        assertions = [
          {
            assertion = !(cfg.tlp && cfg.powerProfilesDaemon);
            message = "myModules.hardware.power: 'tlp' and 'powerProfilesDaemon' are mutually exclusive (both manage power); enable at most one.";
          }
        ];

        # NOTE: governor is NOT set here. The performance module's
        # `powerManagement.cpuFreqGovernor = lib.mkDefault cfg.governor` is the
        # single source of truth. This avoids priority conflicts where mkIf
        # (normal priority) would override mkDefault.

        # TLP — battery charge limits + AC/BAT CPU/platform/wifi profiles.
        services.tlp = lib.mkIf cfg.tlp {
          enable = true;
          settings = {
            START_CHARGE_THRESH_BAT0 = 20;
            STOP_CHARGE_THRESH_BAT0 = 80;
            CPU_SCALING_GOVERNOR_ON_AC = "performance";
            CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
            CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
            CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
            PLATFORM_PROFILE_ON_AC = "performance";
            PLATFORM_PROFILE_ON_BAT = "low-power";
            WIFI_PWR_ON_AC = "off";
            WIFI_PWR_ON_BAT = "on";
            USB_AUTOSUSPEND = 1;
            RUNTIME_PM_ON_AC = "on";
            RUNTIME_PM_ON_BAT = "auto";
          };
        };

      };
    };
in
{
  flake.modules.nixos.hardware-power = mod;

}

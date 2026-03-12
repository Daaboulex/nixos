{ inputs, ... }:
{
  flake.nixosModules.hardware-power =
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
        profile = lib.mkOption {
          type = lib.types.enum [
            "performance"
            "balanced"
            "powersave"
          ];
          default = "balanced";
          description = "Power profile to apply";
        };
        laptop = lib.mkEnableOption "Laptop power optimizations (TLP)";
      };

      config = lib.mkIf cfg.enable {
        # Disable power-profiles-daemon — governor is managed by performance.nix
        # and scx_lavd handles runtime power decisions via its own autopilot/modes.
        services.power-profiles-daemon.enable = lib.mkForce false;

        # NOTE: governor is NOT set here. The performance module's
        # `powerManagement.cpuFreqGovernor = lib.mkDefault cfg.governor` is the
        # single source of truth. This avoids priority conflicts where mkIf
        # (normal priority) would override mkDefault.

        # TLP laptop power management
        services.tlp = lib.mkIf cfg.laptop {
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

        environment.systemPackages = lib.mkIf cfg.laptop [
          pkgs.powertop
          pkgs.acpi
        ];
      };
    };
}

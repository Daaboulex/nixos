{ config, pkgs, lib, ... }:

let
  hostName = config.networking.hostName;
  isAlienware = hostName == "alienware-r7";
  isMacBook = lib.hasPrefix "macbook-pro" hostName;
in
{
  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.hardware.power.enable = lib.mkEnableOption "Power management configuration";

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf config.myModules.hardware.power.enable {
    # Disable power-profiles-daemon (conflicts with TLP and custom settings)
    services.power-profiles-daemon.enable = lib.mkForce false;

    # ==========================================================================
    # Desktop Power Management
    # ==========================================================================
    # For desktop systems (like Alienware), use performance governor
    powerManagement.cpuFreqGovernor = lib.mkIf isAlienware "performance";

    # ==========================================================================
    # Laptop Power Management (TLP)
    # ==========================================================================
    # TLP provides advanced power management for laptops with battery optimization
    services.tlp = lib.mkIf isMacBook {
      enable = true;

      settings = {
        # ----------------------------------------------------------------------
        # Battery Charge Thresholds
        # ----------------------------------------------------------------------
        # Limit battery charging to extend battery lifespan
        # Start charging when battery drops below 20%
        START_CHARGE_THRESH_BAT0 = 20;
        # Stop charging when battery reaches 80%
        STOP_CHARGE_THRESH_BAT0 = 80;

        # ----------------------------------------------------------------------
        # CPU Frequency Scaling
        # ----------------------------------------------------------------------
        # Use mkForce to override NixOS defaults
        CPU_SCALING_GOVERNOR_ON_AC = lib.mkForce "performance";  # Max performance when plugged in
        CPU_SCALING_GOVERNOR_ON_BAT = lib.mkForce "powersave";   # Save power on battery

        # ----------------------------------------------------------------------
        # CPU Energy Performance Policy
        # ----------------------------------------------------------------------
        # Intel P-State driver energy/performance hints
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";  # Favor performance on AC
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";       # Favor power saving on battery

        # ----------------------------------------------------------------------
        # Platform Profiles
        # ----------------------------------------------------------------------
        # ACPI platform profile (if supported by hardware)
        PLATFORM_PROFILE_ON_AC = "performance";
        PLATFORM_PROFILE_ON_BAT = "low-power";

        # ----------------------------------------------------------------------
        # Wireless Power Management
        # ----------------------------------------------------------------------
        WIFI_PWR_ON_AC = "off";   # Disable WiFi power saving on AC
        WIFI_PWR_ON_BAT = "on";   # Enable WiFi power saving on battery

        # ----------------------------------------------------------------------
        # USB and Runtime Power Management
        # ----------------------------------------------------------------------
        USB_AUTOSUSPEND = 1;           # Enable USB autosuspend (1 second)
        RUNTIME_PM_ON_AC = "on";       # Enable runtime PM even on AC
        RUNTIME_PM_ON_BAT = "auto";    # Automatic runtime PM on battery
      };
    };

    # ==========================================================================
    # Power Monitoring Tools
    # ==========================================================================
    # Install power monitoring utilities for laptops
    environment.systemPackages = lib.mkIf isMacBook (with pkgs; [
      powertop  # Power consumption analyzer and tuning tool
      acpi      # ACPI information tool
    ]);
  };
}
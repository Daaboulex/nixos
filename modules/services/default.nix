{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.system.services.enable = lib.mkEnableOption "Common system services";

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf config.myModules.system.services.enable {
    services = {
      # Printing support (CUPS)
      printing = {
        enable = true;
        browsing = true;
        defaultShared = false;
        drivers = [ pkgs.gutenprint pkgs.gutenprintBin ];
      };

      # Touchpad and input device support
      libinput.enable = true;

      # SSD TRIM support (improves SSD lifespan)
      fstrim.enable = true;

      # Early Out-Of-Memory daemon (prevents system freezes)
      earlyoom.enable = true;

      # ACPI daemon (power button events, lid close, etc.)
      acpid.enable = true;

      # Power management daemon
      upower.enable = true;

      # Geolocation service (for timezone, weather, etc.)
      geoclue2.enable = true;

      # iOS device support (iPhone, iPad)
      usbmuxd.enable = true;
    };
  };
}

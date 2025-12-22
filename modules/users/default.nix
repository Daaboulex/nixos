{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.system.users.enable = lib.mkEnableOption "User and group configuration";

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf config.myModules.system.users.enable {
    # Enable Zsh as a system shell
    programs.zsh.enable = true;

    # Define system groups
    users.groups = {
      networkmanager = {};  # Network management
      wheel = {};           # Sudo access
      video = {};           # Video device access
      input = {};           # Input device access
      disk = {};            # Disk management
      bluetooth = {};       # Bluetooth access
      dialout = {};         # Serial port access
      i2c = {};             # I2C device access for DDC
    };

    # Primary user configuration
    users.users.user = {
      isNormalUser = true;
      description = "user";

      # User group memberships
      extraGroups = [
        "networkmanager"
        "wheel"
        "video"
        "input"
        "disk"
        "bluetooth"
        "dialout"
        "i2c"  # For PowerDevil DDC brightness control
      ];

      # Default shell
      shell = pkgs.zsh;
    };
  };
}
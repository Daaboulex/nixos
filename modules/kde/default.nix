{ config, pkgs, lib, ... }:

let
  cfg = config.myModules.desktop.kde;
in
{
  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.desktop.kde = {
    enable = lib.mkEnableOption "KDE Plasma Desktop Environment";
    
    sddm = {
      primaryMonitor = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Primary monitor connector (e.g., 'DP-1'). If set, only this monitor will show SDDM login.";
        example = "DP-1";
      };
      secondaryMonitor = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Secondary monitor connector to disable for SDDM (e.g., 'DP-2').";
        example = "DP-2";
      };
    };
    
    ddcBrightness = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable i2c for PowerDevil DDC brightness control (only enable if your monitor supports DDC/CI)";
    };
  };

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf config.myModules.desktop.kde.enable {
    # ==========================================================================
    # KDE Plasma 6 Desktop Environment
    # ==========================================================================
    services.desktopManager.plasma6.enable = true;

    # ==========================================================================
    # SDDM Display Manager with Wayland
    # ==========================================================================
    services.displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };
      defaultSession = "plasma";
    };

    # ==========================================================================
    # X Server (still needed for some legacy apps)
    # ==========================================================================
    services.xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };

    # ==========================================================================
    # Multi-Monitor Boot Configuration
    # ==========================================================================
    boot.kernelParams = lib.optionals (cfg.sddm.secondaryMonitor != null) [
      "video=${cfg.sddm.secondaryMonitor}:panel_orientation=right_side_up"
    ];


    # ==========================================================================
    # KDE Plasma 6 Packages (NixOS Wiki Recommended)
    # ==========================================================================
    environment.systemPackages = with pkgs; [
      # Core KDE utilities
      kdePackages.sddm-kcm           # SDDM configuration module
      
      # Portal
      xdg-desktop-portal
    ];

    # ==========================================================================
    # Exclude Bloat Packages
    # ==========================================================================
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      elisa            # Music player (use VLC instead)
      kmahjongg        # Games
      kmines           # Games
      kpat             # Solitaire
      ksudoku          # Games
    ];

    # ==========================================================================
    # i2c Support for PowerDevil DDC brightness control
    # ==========================================================================
    hardware.i2c.enable = cfg.ddcBrightness;

    # ==========================================================================
    # XDG Portal Configuration
    # ==========================================================================
    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = [ 
        pkgs.xdg-desktop-portal-gtk 
        pkgs.kdePackages.xdg-desktop-portal-kde 
      ];
    };

    # ==========================================================================
    # Locale Settings
    # ==========================================================================
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    environment.variables = {
      LC_ALL = lib.mkDefault "en_US.UTF-8";
    };
  };
}

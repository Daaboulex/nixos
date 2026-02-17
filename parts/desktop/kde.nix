{ inputs, ... }: {
  flake.nixosModules.desktop-kde = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.desktop.kde;
    in {
      options.myModules.desktop.kde = {
        enable = lib.mkEnableOption "KDE Plasma Desktop Environment";
        
        sddm = {
          primaryMonitor = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Primary monitor for SDDM login";
          };
          secondaryMonitor = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Secondary monitor to disable for SDDM";
          };
        };
        
        ddcBrightness = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable i2c for PowerDevil DDC brightness control";
        };
      };

      config = lib.mkIf cfg.enable {
        services.desktopManager.plasma6.enable = true;
        
        services.displayManager = {
          sddm = {
            enable = true;
            wayland.enable = true;
          };
          defaultSession = "plasma";
        };

        services.xserver = {
          enable = true;
          xkb = { layout = "us"; variant = ""; };
        };

        boot.kernelParams = lib.optionals (cfg.sddm.secondaryMonitor != null) [
          "video=${cfg.sddm.secondaryMonitor}:panel_orientation=right_side_up"
        ];

        environment.systemPackages = with pkgs; [
          kdePackages.sddm-kcm
          xdg-desktop-portal
        ];

        environment.plasma6.excludePackages = with pkgs.kdePackages; [
          elisa kmahjongg kmines kpat ksudoku
        ];

        hardware.i2c.enable = cfg.ddcBrightness;

        xdg.portal = {
          enable = true;
          xdgOpenUsePortal = true;
          extraPortals = [ 
            pkgs.xdg-desktop-portal-gtk 
            pkgs.kdePackages.xdg-desktop-portal-kde 
          ];
        };
        # KDE Connect firewall rules
        networking.firewall = {
          allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
          allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];
        };

        i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
        environment.variables.LC_ALL = lib.mkDefault "en_US.UTF-8";
      };
    };
}

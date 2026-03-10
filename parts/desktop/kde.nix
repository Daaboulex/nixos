{ inputs, ... }:
{
  flake.nixosModules.desktop-kde =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.desktop.kde;
    in
    {
      _class = "nixos";
      options.myModules.desktop.kde = {
        enable = lib.mkEnableOption "KDE Plasma Desktop Environment";

        xkbLayout = lib.mkOption {
          type = lib.types.str;
          default = "us";
          description = "XKB keyboard layout (e.g. 'us', 'de', 'us,de')";
        };
        xkbVariant = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "XKB keyboard variant";
        };
        ddcBrightness = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "i2c for PowerDevil DDC brightness control";
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
          xkb = {
            layout = cfg.xkbLayout;
            variant = cfg.xkbVariant;
          };
        };

        environment.systemPackages = with pkgs; [
          kdePackages.sddm-kcm
          xdg-desktop-portal
        ];

        environment.plasma6.excludePackages = with pkgs.kdePackages; [
          elisa
          kmahjongg
          kmines
          kpat
          ksudoku
        ];

        hardware.i2c.enable = cfg.ddcBrightness;

        xdg.portal = {
          enable = true;
          xdgOpenUsePortal = true;
          extraPortals = [
            pkgs.kdePackages.xdg-desktop-portal-kde
          ];
        };
        # KDE Connect firewall rules
        networking.firewall = {
          allowedTCPPortRanges = [
            {
              from = 1714;
              to = 1764;
            }
          ];
          allowedUDPPortRanges = [
            {
              from = 1714;
              to = 1764;
            }
          ];
        };

        i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
        environment.variables.LC_ALL = lib.mkDefault "en_US.UTF-8";
        environment.sessionVariables = {
          NIXOS_OZONE_WL = "1";
          SDL_VIDEODRIVER = "wayland";
        };
      };
    };
}

# panels — Plasma bottom panel with all widgets (launcher, pager, tasks, tray, clock).
{
  config,
  lib,
  ...
}:

let
  cfg = config.myModules.home.plasma.panels;
in
{
  options.myModules.home.plasma.panels = {
    enable = lib.mkEnableOption "Plasma panel layout and widgets";
    showPager = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include the virtual desktop pager widget in the panel.";
    };
    height = lib.mkOption {
      type = lib.types.int;
      default = 48;
      description = "Panel height in pixels.";
    };
    screen = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Pin panel to a specific screen index (0-based). null = Plasma default.";
    };
    pinnedLaunchers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "applications:systemsettings.desktop"
        "preferred://filemanager"
      ];
      description = ''
        Icon-tasks pinned launchers (desktop-ids / file:// uris). Defaults to
        always-present KDE entries; hosts append app-specific pins (e.g. flatpak
        exports) so this shared module never references host-specific apps.
      '';
    };
    hiddenTrayItems = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "plasmashell_microphone" ];
      description = ''
        System-tray entries forced into the hidden (popup-only) area, keyed by
        plasmoid id or StatusNotifierItem Id. plasmashell_microphone is the
        microphone-in-use privacy indicator: wine and CEF processes open brief
        audio-capture probes on every game launch, which makes that indicator
        strobe in the visible bar on gaming hosts; hiding it keeps it
        inspectable in the popup without the flicker.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.plasma.panels = lib.mkDefault [
      (
        {
          location = "bottom";
          inherit (cfg) height;
          floating = false; # Disable floating dock (User Request)
          lengthMode = "fill";
          widgets = [
            # Application Launcher (Kickoff)
            {
              name = "org.kde.plasma.kickoff";
              config.General = {
                favoritesPortedToKAstats = "true";
              };
            }
          ]
          # Virtual Desktop Pager — optional per host
          ++ lib.optional cfg.showPager "org.kde.plasma.pager"
          ++ [
            # Icon Tasks (Task Manager)
            {
              name = "org.kde.plasma.icontasks";
              config.General = {
                launchers = lib.mkDefault cfg.pinnedLaunchers;
              };
            }
            # Separator
            "org.kde.plasma.marginsseparator"
            # System Tray
            {
              systemTray = lib.optionalAttrs (cfg.hiddenTrayItems != [ ]) {
                items.hidden = cfg.hiddenTrayItems;
              };
            }
            # Digital Clock — 24h, day month year
            {
              name = "org.kde.plasma.digitalclock";
              config.Appearance = {
                use24hFormat = "2"; # 2 = force 24h (0 = locale, 1 = force 12h)
                dateFormat = "custom";
                customDateFormat = "dddd, d MMMM yyyy";
                dateDisplayFormat = "BelowTime";
              };
            }
          ];
        }
        // lib.optionalAttrs (cfg.screen != null) { inherit (cfg) screen; }
      )
    ];
  };
}

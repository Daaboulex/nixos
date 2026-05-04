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
    screen = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Pin panel to a specific screen index (0-based). null = Plasma default.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.plasma.panels = lib.mkDefault [
      (
        {
          location = "bottom";
          height = 48;
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
                launchers = lib.mkDefault [
                  "file://${config.home.homeDirectory}/.local/share/flatpak/exports/share/applications/io.gitlab.librewolf-community.desktop"
                  "file://${config.home.homeDirectory}/.local/share/flatpak/exports/share/applications/io.github.ungoogled_software.ungoogled_chromium.desktop"
                  "file://${config.home.homeDirectory}/.local/share/flatpak/exports/share/applications/eu.betterbird.Betterbird.desktop"
                  "applications:systemsettings.desktop"
                  "preferred://filemanager"
                ];
              };
            }
            # Separator
            "org.kde.plasma.marginsseparator"
            # System Tray
            {
              name = "org.kde.plasma.systemtray";
              config.General = {
                showVirtualDevices = "true";
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

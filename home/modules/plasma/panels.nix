# Plasma Panel Configuration
# Bottom panel with all widgets (launcher, pager, tasks, tray, clock)
{ config, lib, ... }:

let
  # Helper for cleaner flatpak app references
  flatpakApp =
    id:
    "file://${config.home.homeDirectory}/.local/share/flatpak/exports/share/applications/${id}.desktop";
in
{
  programs.plasma.panels = [
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
        # Virtual Desktop Pager
        "org.kde.plasma.pager"
        # Icon Tasks (Task Manager)
        {
          name = "org.kde.plasma.icontasks";
          config.General = {
            launchers = lib.mkDefault [
              (flatpakApp "io.gitlab.librewolf-community")
              (flatpakApp "io.github.ungoogled_software.ungoogled_chromium")
              (flatpakApp "eu.betterbird.Betterbird")
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
        # Digital Clock — force 24h, locale-default date styling
        {
          name = "org.kde.plasma.digitalclock";
          config.Appearance = {
            use24hFormat = "2"; # 2 = force 24h (0 = locale, 1 = force 12h)
          };
        }
      ];
    }
  ];
}

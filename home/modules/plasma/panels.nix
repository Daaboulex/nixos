# Plasma Panel Configuration
# Bottom panel with all widgets (launcher, pager, tasks, tray, clock)
{ config, pkgs, lib, ... }:

let
  # Helper for cleaner flatpak app references
  flatpakApp = id: "file://${config.home.homeDirectory}/.local/share/flatpak/exports/share/applications/${id}.desktop";
in
{
  # ---- Fix: enforce non-floating on every login ----
  # Plasma 6 Wayland defaults to floating=true. The panel JS only runs when its
  # content changes (hash check), so any crash/restart resets floating=1 and it
  # sticks. This desktopScript runs AFTER panel creation (priority 3 > 2) and
  # forces floating=false on every login regardless of hash state.
  programs.plasma.startup.desktopScript."fix-floating" = {
    text = ''
      panels().forEach(function(panel) {
        panel.floating = false;
      });
    '';
    priority = 3;
    runAlways = true;
  };

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
        # Digital Clock — 24h, German date format (dd.MM.yyyy)
        {
          name = "org.kde.plasma.digitalclock";
          config.Appearance = {
            autoFontAndSize = "true";
            fontWeight = "400";
            use24hFormat = "2";           # 2 = force 24h (0 = locale, 1 = force 12h)
            dateFormat = "custom";
            customDateFormat = "dd.MM.yyyy";
            dateDisplayFormat = "BesideTime";  # "BesideTime" or "BelowTime"
            showDate = "true";
            showSeconds = "Never";        # "Never", "InToolTip", "Always"
          };
        }
      ];
    }
  ];
}

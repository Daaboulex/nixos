# Plasma KWin Window Manager
# Virtual desktops, tiling, night light, effects, and configFile overrides
{ config, pkgs, lib, osConfig, ... }:

{
  programs.plasma = {
    # ==========================================================================
    # KWin - Window Manager
    # ==========================================================================
    kwin = {
      # ---- Virtual Desktops ----
      virtualDesktops = {
        number = lib.mkDefault 1;
        rows = lib.mkDefault 1;
      };

      # ---- Tiling (managed by Fluid Tile script) ----
      tiling = {
        padding = lib.mkDefault 0;
      };

      # ---- Night Light ----
      nightLight = {
        enable = lib.mkDefault true;
        mode = lib.mkDefault "location";
        location = lib.mkDefault {
          latitude = "52.52";      # Berlin — override per-host if needed
          longitude = "13.405";
        };
      };

      # ---- Titlebar Buttons (commented — using KDE defaults) ----
      # titlebarButtons = {
      #   left = [ "more-window-actions" "application-menu" ];
      #   right = [ "minimize" "maximize" "close" ];
      # };

      # ---- Effects (only set non-default values) ----
      # All null values omitted — plasma-manager already defaults to null.
      # Uncomment and set to override KDE defaults per-host.
    };

    # ==========================================================================
    # Config Files — KWin settings without native options
    # ==========================================================================
    configFile = {
      # ---- Fluid Tile — Auto-tiling KWin script ----
      "kwinrc"."Plugins"."fluid-tileEnabled" = lib.mkDefault true;
      "kwinrc"."Plugins"."late-tileEnabled" = lib.mkDefault true;
      "kwinrc"."Plugins"."krohnkiteEnabled" = lib.mkDefault false;
      "kwinrc"."Plugins"."poloniumEnabled" = lib.mkDefault false;

      "kwinrc"."Script-fluid-tile" = {
        # -- Blocklist --
        AppsBlocklist = lib.mkDefault (lib.concatStringsSep "," [
          # Fluid Tile defaults (KDE internals)
          "moonlight" "org.kde.xwaylandvideobridge" "wl-paste" "wl-copy"
          "org.kde.kded6" "qt-sudo" "org.kde.polkit-kde-authentication-agent-1"
          "org.kde.spectacle" "kcm_kwinrules" "org.freedesktop.impl.portal.desktop.kde"
          "krunner" "plasmashell" "org.kde.plasmashell" "kwin_wayland"
          "ksmserver-logout-greeter"
          # Wine/Proton helper windows & anti-cheat
          "easyanticheat" "battleye" "wine" "explorer.exe"
          # KDE utilities that break when tiled
          "pinentry-qt" "org.kde.kwalletd6" "org.kde.plasma.emojier"
          "org.kde.drkonqi" "org.kde.kcolorchooser"
        ]);

        # -- Tile Priority --
        TilesPriority = lib.mkDefault "Height,Width,Left,Top,Right,Bottom";

        # -- Window Behavior --
        MaximizeExtend = lib.mkDefault true;
        WindowsOrderOpen = lib.mkDefault true;
        WindowsOrderClose = lib.mkDefault true;
        ModalsIgnore = lib.mkDefault true;

        # -- Animation (>= KDE animation duration) --
        WindowsExtendTileChangedDelay = lib.mkDefault 300;

        # -- Overflow: switch to layout with more tiles --
        WindowOverflowAction = lib.mkDefault 4;

        # -- Virtual Desktop Cleanup --
        DesktopRemove = lib.mkDefault true;
        DesktopRemoveMin = lib.mkDefault 1;
        DesktopRemoveDelay = lib.mkDefault 500;
        DesktopExtra = lib.mkDefault false;

        # -- Layout: two-column for new desktops --
        LayoutDefault = lib.mkDefault 2;

        # -- UI --
        UIMode = lib.mkDefault 0;
        UIWindowCompactPosition = lib.mkDefault 1;
        UIWindowCursor = lib.mkDefault false;
      };

      # ---- KWin Window Behavior (no native equivalents) ----
      "kwinrc"."Windows" = {
        SeparateScreenFocus = lib.mkDefault true;
        ActiveMouseScreen = lib.mkDefault true;
        FocusPolicy = lib.mkDefault "ClickToFocus";
        FocusStealingPreventionLevel = lib.mkDefault 1;
        AutoRaise = lib.mkDefault false;
        AutoRaiseInterval = lib.mkDefault 0;
        NextFocusPrefersMouse = lib.mkDefault true;
      };

      "kwinrc"."Compositing" = {
        AllowTearing = lib.mkDefault false;
      };

      "kwinrc"."Effect-overview" = {
        BorderActivate = lib.mkDefault 9;               # Disable hot corner
      };

      "kwinrc"."ElectricBorders" = {
        TopLeft = lib.mkDefault 0;
        TopRight = lib.mkDefault 0;
        BottomLeft = lib.mkDefault 0;
        BottomRight = lib.mkDefault 0;
      };

      "kwinrc"."TabBox" = {
        LayoutName = lib.mkDefault "compact";
      };

      "kwinrc"."Xwayland" = {
        Scale = lib.mkDefault 1;
      };

      "kwinrc"."ModifierOnlyShortcuts" = {
        Meta = lib.mkDefault "org.kde.plasmashell,/PlasmaShell,org.kde.PlasmaShell,activateLauncherMenu";
      };
    };
  };
}

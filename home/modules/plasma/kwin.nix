# Plasma KWin Window Manager
# Virtual desktops, tiling, night light, effects, and configFile overrides
{ config, pkgs, lib, osConfig, ... }:

{
  programs.plasma = {
    # ==========================================================================
    # KWin - Window Manager
    # ==========================================================================
    kwin = {
      # ---- Virtual Desktops (migrated from kwinrc.Desktops) ----
      virtualDesktops = {
        number = lib.mkDefault 1;
        rows = lib.mkDefault 1;
        # names = [ "Desktop 1" ];
      };

      # ---- Tiling (managed by Fluid Tile script) ----
      # Per-screen layouts are host-specific (set via home.activation.configureTiling in host config)
      tiling = {
        padding = lib.mkDefault 0;
      };

      # ---- Night Light (migrated from kwinrc.NightColor) ----
      nightLight = {
        enable = lib.mkDefault true;
        mode = lib.mkDefault "location"; # "constant", "location", or "times"
        # temperature = {
        #   day = 6500;
        #   night = 4500;
        # };
        # Location set per-host via osConfig.time.timeZone or override in home/hosts/
        location = lib.mkDefault {
          latitude = "52.52";
          longitude = "13.405";
        };
        # For mode = "times":
        # time = {
        #   morning = "06:00";
        #   evening = "18:00";
        # };
      };

      # ---- Titlebar Buttons ----
      # titlebarButtons = {
      #   left = [ "more-window-actions" "application-menu" ];
      #   right = [ "minimize" "maximize" "close" ];
      # };

      # ---- Edge/Corner Barriers ----
      cornerBarrier = null; # null = default (true)
      edgeBarrier = null; # null = default (some value)
      borderlessMaximizedWindows = null;

      # ---- Effects (null = KDE defaults) ----
      effects = {
        # Desktop switching animation
        desktopSwitching = {
          animation = null; # null = default ("slide")
          navigationWrapping = null;
        };

        # Window open/close animation
        windowOpenClose = {
          animation = null; # null = default ("scale" or "glide")
        };

        # Minimization animation
        minimization = {
          animation = null; # null = default ("squash")
          # duration = 200;        # Only for magiclamp
        };

        # Blur (null = use system default)
        blur = {
          enable = null; # null = default
          # strength = 10;
          # noiseStrength = 0;
        };

        # Dim inactive windows
        dimInactive = {
          enable = null; # null = default (false)
        };

        # Dim when requesting admin privileges
        dimAdminMode = {
          enable = null; # null = default (true)
        };

        # Wobbly windows
        wobblyWindows = {
          enable = null; # null = default (false)
        };

        # Shake cursor to find it
        shakeCursor = {
          enable = null; # null = default (true on laptops)
        };

        # Translucent windows
        translucency = {
          enable = null; # null = default (false)
        };

        # Slide back windows
        slideBack = {
          enable = null; # null = default
        };

        # Snap helper (shows center guides)
        snapHelper = {
          enable = null; # null = default (false)
        };

        # Fall apart on close
        fallApart = {
          enable = null; # null = default (false)
        };

        # Cube effect
        cube = {
          enable = null; # null = default (false)
        };

        # FPS counter
        fps = {
          enable = null; # null = default (false)
        };

        # Invert colors toggle
        invert = {
          enable = null; # null = default (false)
        };

        # Magnifier
        magnifier = {
          enable = null; # null = default (false)
          # width = 200;
          # height = 200;
        };

        # Zoom accessibility
        zoom = {
          enable = null; # null = default
          # zoomFactor = 1.2;
          # mousePointer = "scale";
          # mouseTracking = "proportional";
        };

        # Hide cursor
        hideCursor = {
          enable = null;
          # hideOnTyping = true;
          # hideOnInactivity = 5;
        };
      };

    };

    # ==========================================================================
    # Config Files — KWin settings without native options
    # ==========================================================================
    configFile = {
      # ---- Fluid Tile — Auto-tiling KWin script ----
      "kwinrc"."Plugins"."fluid-tileEnabled" = lib.mkDefault true;
      "kwinrc"."Plugins"."late-tileEnabled" = lib.mkDefault true;
      "kwinrc"."Plugins"."krohnkiteEnabled" = lib.mkDefault false;   # Explicitly disable unused tiling scripts
      "kwinrc"."Plugins"."poloniumEnabled" = lib.mkDefault false;

      "kwinrc"."Script-fluid-tile" = {
        # -- Blocklist --
        # Only blocklist apps that genuinely break when tiled.
        # ModalsIgnore = true handles popups/dialogs automatically.
        # Games run fullscreen so they don't need blocklisting.
        AppsBlocklist = lib.mkDefault (lib.concatStringsSep "," [
          # Fluid Tile defaults (KDE internals — must keep)
          "moonlight" "org.kde.xwaylandvideobridge" "wl-paste" "wl-copy"
          "org.kde.kded6" "qt-sudo" "org.kde.polkit-kde-authentication-agent-1"
          "org.kde.spectacle" "kcm_kwinrules" "org.freedesktop.impl.portal.desktop.kde"
          "krunner" "plasmashell" "org.kde.plasmashell" "kwin_wayland"
          "ksmserver-logout-greeter"
          # Wine/Proton helper windows & anti-cheat popups
          "easyanticheat" "battleye" "wine" "explorer.exe"
          # KDE utilities that break when tiled (popups, pinentry, color pickers)
          "pinentry-qt" "org.kde.kwalletd6" "org.kde.plasma.emojier"
          "org.kde.drkonqi" "org.kde.kcolorchooser"
        ]);

        # -- Tile Priority --
        # Height first → master tile (full-height left column) fills before stacked tiles
        # Then Left → prefer left side, then Top → top-right before bottom-right
        TilesPriority = lib.mkDefault "Height,Width,Left,Top,Right,Bottom";

        # -- Window Behavior --
        MaximizeExtend = lib.mkDefault true;       # Maximize when alone on screen (single window = fullscreen)
        WindowsOrderOpen = lib.mkDefault true;     # Retile all windows when a new one opens
        WindowsOrderClose = lib.mkDefault true;    # Retile remaining windows when one closes (fill gaps)
        ModalsIgnore = lib.mkDefault true;         # Ignore dialog/transient/popup windows

        # -- Animation --
        # Must be >= KDE animation duration. AnimationDurationFactor=0.7 → ~250ms
        WindowsExtendTileChangedDelay = lib.mkDefault 300;

        # -- Overflow (v7.0 replaces DesktopAdd/DesktopAddMode) --
        # When all tiles on a screen are full:
        #   0 = New desktop after current    4 = Switch to next layout (all desktops)
        #   1 = New desktop before current   5 = Switch to next layout (current screen)
        #   2 = New desktop at end           6 = Just let it float
        #   3 = New desktop at beginning
        WindowOverflowAction = lib.mkDefault 4;    # Switch to layout with more tiles (dynamic growth)

        # -- Virtual Desktop Cleanup --
        DesktopRemove = lib.mkDefault true;        # Auto-remove empty desktops when windows close
        DesktopRemoveMin = lib.mkDefault 1;        # Always keep at least 1 desktop
        DesktopRemoveDelay = lib.mkDefault 500;    # Wait 500ms before removing (avoids flicker during moves)
        DesktopExtra = lib.mkDefault false;

        # -- Layout --
        # Default layout for NEW virtual desktops (created by overflow):
        #   1 = Single    2 = Two-column   3 = Top/bottom
        #   4 = Master+stack (left + stacked right)
        #   5 = Stacked left + right   6 = 2×2 grid
        LayoutDefault = lib.mkDefault 2;

        # -- UI --
        UIMode = lib.mkDefault 0;                  # Fullscreen overlay for layout switching
        UIWindowCompactPosition = lib.mkDefault 1; # Compact bar at top
        UIWindowCursor = lib.mkDefault false;
      };

      # ---- KWin Settings (no native equivalents) ----
      "kwinrc"."Windows" = {
        SeparateScreenFocus = lib.mkDefault true;       # Each screen has independent focus (essential for multi-monitor tiling)
        ActiveMouseScreen = lib.mkDefault true;         # Active screen follows mouse (switches focus target screen)
        FocusPolicy = lib.mkDefault "ClickToFocus";     # Click-to-focus keeps tiled windows stable
        FocusStealingPreventionLevel = lib.mkDefault 1; # Low — let new windows take focus (important for tiled window placement)
        AutoRaise = lib.mkDefault false;                # Don't auto-raise on hover (would disrupt tiled layout)
        AutoRaiseInterval = lib.mkDefault 0;
        NextFocusPrefersMouse = lib.mkDefault true;     # When closing a window, focus the one under cursor (not random tile)
      };

      "kwinrc"."Compositing" = {
        AllowTearing = lib.mkDefault false;             # No tearing — consistent frame delivery
      };

      "kwinrc"."Effect-overview" = {
        BorderActivate = lib.mkDefault 9;               # Disable hot corner overview trigger (9 = none)
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

      # ---- Fix Meta key opening Launcher (Intercepts caps:super and normal Meta) ----
      "kwinrc"."ModifierOnlyShortcuts" = {
        Meta = lib.mkDefault "org.kde.plasmashell,/PlasmaShell,org.kde.PlasmaShell,activateLauncherMenu";
      };
    };
  };
}

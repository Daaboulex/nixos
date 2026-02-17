# Plasma Manager Configuration
# Declarative KDE Plasma settings via Home Manager
# Migrated to native options where available, with all modules as templates
{ config, pkgs, lib, inputs, ... }:

let
  # Helper for cleaner flatpak app references
  flatpakApp = id: "file:///home/user/.local/share/flatpak/exports/share/applications/${id}.desktop";
in {
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  # ============================================================================
  # User Packages
  # ============================================================================
  home.packages = with pkgs; [
    # Core KDE utilities
    kdePackages.kcalc              # Calculator
    kdePackages.kcharselect        # Special character selector
    kdePackages.kclock             # Clock app
    kdePackages.kcolorchooser      # Color picker
    # File management & disk tools
    kdePackages.filelight          # Disk usage analyzer
    kdePackages.isoimagewriter     # Write ISO to USB
    kdePackages.partitionmanager   # Partition manager
    kdePackages.plasma-disks       # Disk health monitoring
    kdePackages.kio-extras         # Additional KIO protocols

    # System & Connectivity
    kdePackages.kdeconnect-kde     # Phone integration
    kdePackages.ksystemlog         # System log viewer
    kdePackages.baloo              # File indexer
    
    # Wayland utilities
    wayland-utils
    wl-clipboard                   # Clipboard
  ];

  # ============================================================================
  # PROGRAMS.PLASMA - Main Configuration
  # ============================================================================
  programs.plasma = {
    enable = true;

    # ==========================================================================
    # Workspace Settings
    # ==========================================================================
    workspace = {
      clickItemTo = "select";
      lookAndFeel = "org.kde.breezedark.desktop";
    };

    # ==========================================================================
    # Fonts (commented - using system defaults)
    # ==========================================================================
    # fonts = {
    #   general = {
    #     family = "Noto Sans";
    #     pointSize = 10;
    #   };
    #   fixedWidth = {
    #     family = "JetBrainsMono Nerd Font";
    #     pointSize = 10;
    #   };
    #   small = {
    #     family = "Noto Sans";
    #     pointSize = 8;
    #   };
    #   toolbar = {
    #     family = "Noto Sans";
    #     pointSize = 10;
    #   };
    #   menu = {
    #     family = "Noto Sans";
    #     pointSize = 10;
    #   };
    #   windowTitle = {
    #     family = "Noto Sans";
    #     pointSize = 10;
    #   };
    # };

    # ==========================================================================
    # Desktop Icons (commented - using defaults)
    # ==========================================================================
    # desktop = {
    #   icons = {
    #     size = 3;                    # 0-6, default is 3
    #     alignment = "left";          # "left" or "right"
    #     arrangement = "topToBottom"; # "leftToRight" or "topToBottom"
    #     lockInPlace = false;
    #     sorting = {
    #       mode = "name";             # "name", "size", "type", "date", "manual"
    #       descending = false;
    #       foldersFirst = true;
    #     };
    #   };
    # };

    # ==========================================================================
    # Input Devices
    # ==========================================================================
    input = {
      keyboard = {
        numlockOnStartup = "on";
        # layouts = [
        #   { layout = "us"; }
        #   { layout = "de"; }
        # ];
        # repeatDelay = 600;
        # repeatRate = 25.0;
      };
      # mice = [
      #   {
      #     name = "Logitech G502";
      #     vendorId = "046d";
      #     productId = "c077";
      #     acceleration = 0.0;
      #     accelerationProfile = "none";
      #   }
      # ];
      # touchpads = [];
    };

    # ==========================================================================
    # KRunner
    # ==========================================================================
    krunner = {
      position = "center";        # Migrated from krunnerrc.General.FreeFloating
      historyBehavior = null;     # null = default ("enableSuggestions")
      activateWhenTypingOnDesktop = null;  # null = default
      # shortcuts = {
      #   launch = "Meta";
      #   runCommandOnClipboard = null;
      # };
    };

    # ==========================================================================
    # KScreenLocker (commented - using defaults)
    # ==========================================================================
    # kscreenlocker = {
    #   autoLock = true;
    #   timeout = 5;                # Minutes until lock
    #   lockOnResume = true;
    #   passwordRequired = true;
    #   passwordRequiredDelay = 0;  # Seconds
    #   appearance = {
    #     alwaysShowClock = true;
    #     showMediaControls = true;
    #     # wallpaper = /path/to/wallpaper.png;
    #   };
    # };

    # ==========================================================================
    # KWin - Window Manager
    # ==========================================================================
    kwin = {
      # ---- Virtual Desktops (migrated from kwinrc.Desktops) ----
      virtualDesktops = {
        number = 1;
        rows = 1;
        # names = [ "Desktop 1" ];
      };

      # ---- Tiling (migrated from kwinrc.Tiling) ----
      tiling = {
        padding = 4;
        # layout = {
        #   id = "custom-layout-id";
        #   tiles = { ... };
        # };
      };

      # ---- Night Light (migrated from kwinrc.NightColor) ----
      nightLight = {
        enable = true;
        mode = "location";         # "constant", "location", or "times"
        # temperature = {
        #   day = 6500;
        #   night = 4500;
        # };
        location = {
          latitude = "52.52";      # Berlin coordinates
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
      cornerBarrier = null;        # null = default (true)
      edgeBarrier = null;          # null = default (some value)
      borderlessMaximizedWindows = null;

      # ---- Effects (null = KDE defaults) ----
      effects = {
        # Desktop switching animation
        desktopSwitching = {
          animation = null;        # null = default ("slide")
          navigationWrapping = null;
        };

        # Window open/close animation
        windowOpenClose = {
          animation = null;        # null = default ("scale" or "glide")
        };

        # Minimization animation
        minimization = {
          animation = null;        # null = default ("squash")
          # duration = 200;        # Only for magiclamp
        };

        # Blur (null = use system default)
        blur = {
          enable = null;           # null = default
          # strength = 10;
          # noiseStrength = 0;
        };

        # Dim inactive windows
        dimInactive = {
          enable = null;           # null = default (false)
        };

        # Dim when requesting admin privileges
        dimAdminMode = {
          enable = null;           # null = default (true)
        };

        # Wobbly windows
        wobblyWindows = {
          enable = null;           # null = default (false)
        };

        # Shake cursor to find it
        shakeCursor = {
          enable = null;           # null = default (true on laptops)
        };

        # Translucent windows
        translucency = {
          enable = null;           # null = default (false)
        };

        # Slide back windows
        slideBack = {
          enable = null;           # null = default
        };

        # Snap helper (shows center guides)
        snapHelper = {
          enable = null;           # null = default (false)
        };

        # Fall apart on close
        fallApart = {
          enable = null;           # null = default (false)
        };

        # Cube effect
        cube = {
          enable = null;           # null = default (false)
        };

        # FPS counter
        fps = {
          enable = null;           # null = default (false)
        };

        # Invert colors toggle
        invert = {
          enable = null;           # null = default (false)
        };

        # Magnifier
        magnifier = {
          enable = null;           # null = default (false)
          # width = 200;
          # height = 200;
        };

        # Zoom accessibility
        zoom = {
          enable = null;           # null = default
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

      # ---- Tiling Scripts (disabled - using native tiling) ----
      scripts = {
        polonium = {
          enable = false;
          # settings = { ... };
        };
      };
    };

    # ==========================================================================
    # Power Management (commented - using system defaults)
    # ==========================================================================
    # powerdevil = {
    #   AC = {
    #     autoSuspend = {
    #       action = "sleep";
    #       idleTimeout = 600;
    #     };
    #     dimDisplay = {
    #       enable = true;
    #       idleTimeout = 300;
    #     };
    #     turnOffDisplay = {
    #       idleTimeout = 600;
    #     };
    #     powerProfile = "performance";
    #   };
    #   battery = {
    #     autoSuspend = {
    #       action = "sleep";
    #       idleTimeout = 300;
    #     };
    #     dimDisplay = {
    #       enable = true;
    #       idleTimeout = 120;
    #     };
    #     turnOffDisplay = {
    #       idleTimeout = 300;
    #     };
    #     powerProfile = "balanced";
    #   };
    #   lowBattery = {
    #     autoSuspend = {
    #       action = "hibernate";
    #       idleTimeout = 120;
    #     };
    #     powerProfile = "powerSaving";
    #   };
    # };

    # ==========================================================================
    # Hotkeys (custom commands)
    # ==========================================================================
    # hotkeys = {
    #   commands = {
    #     "launch-htop" = {
    #       name = "Launch htop";
    #       key = "Meta+H";
    #       command = "konsole -e htop";
    #     };
    #   };
    # };

    # ==========================================================================
    # Panel Configuration
    # ==========================================================================
    panels = [
      {
        location = "bottom";
        screen = 0;
        height = 44;
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
              launchers = [
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
          # Digital Clock
          {
            name = "org.kde.plasma.digitalclock";
            config.Appearance = {
              fontWeight = "400";
            };
          }
        ];
      }
    ];

    # ==========================================================================
    # Keyboard Shortcuts
    # ==========================================================================
    shortcuts = {
      # ========================================================================
      # KWin Window Management (Core)
      # ========================================================================
      kwin."Activate Window Demanding Attention" = "Meta+Ctrl+A";
      kwin."Edit Tiles" = "Meta+T";
      kwin.Expose = "Ctrl+F9";
      kwin.ExposeAll = ["Ctrl+F10" "Launch (C)"];
      kwin.ExposeClass = "Ctrl+F7";
      kwin."Grid View" = "Meta+G";
      kwin."Kill Window" = "Meta+Ctrl+Esc";
      kwin.Overview = "Meta+W";
      kwin."Show Desktop" = "Meta+D";
      kwin."Window Close" = "Meta+Q";
      kwin."Window Maximize" = "Meta+PgUp";
      kwin."Window Minimize" = "Meta+PgDown";
      kwin."Window Operations Menu" = "Alt+F3";
      
      # ---- Desktop Switching ----
      kwin."Switch One Desktop Down" = "Meta+Ctrl+Down";
      kwin."Switch One Desktop Up" = "Meta+Ctrl+Up";
      kwin."Switch One Desktop to the Left" = "Meta+Ctrl+Left";
      kwin."Switch One Desktop to the Right" = "Meta+Ctrl+Right";
      kwin."Switch to Desktop 1" = "Ctrl+F1";
      kwin."Switch to Desktop 2" = "Ctrl+F2";
      kwin."Switch to Desktop 3" = "Ctrl+F3";
      kwin."Switch to Desktop 4" = "Ctrl+F4";
      
      # ---- Window Movement ----
      kwin."Switch Window Down" = "Meta+Alt+Down";
      kwin."Switch Window Left" = "Meta+Alt+Left";
      kwin."Switch Window Right" = "Meta+Alt+Right";
      kwin."Switch Window Up" = "Meta+Alt+Up";
      
      # ---- Window Switching ----
      kwin."Walk Through Windows" = ["Meta+Tab" "Alt+Tab"];
      kwin."Walk Through Windows (Reverse)" = ["Meta+Shift+Tab" "Alt+Shift+Tab"];
      kwin."Walk Through Windows of Current Application" = ["Meta+\`" "Alt+\`"];
      kwin."Walk Through Windows of Current Application (Reverse)" = ["Meta+~" "Alt+~"];

      # ---- Quick Tile ----
      kwin."Window Quick Tile Bottom" = "Meta+Down";
      kwin."Window Quick Tile Left" = "Meta+Left";
      kwin."Window Quick Tile Right" = "Meta+Right";
      kwin."Window Quick Tile Top" = "Meta+Up";

      # ---- Window to Desktop ----
      kwin."Window One Desktop Down" = "Meta+Ctrl+Shift+Down";
      kwin."Window One Desktop Up" = "Meta+Ctrl+Shift+Up";
      kwin."Window One Desktop to the Left" = "Meta+Ctrl+Shift+Left";
      kwin."Window One Desktop to the Right" = "Meta+Ctrl+Shift+Right";
      kwin."Window to Next Screen" = "Meta+>";
      kwin."Window to Previous Screen" = "Meta+<";

      # ---- Zoom & Input ----
      kwin.MoveMouseToCenter = "Meta+F6";
      kwin.MoveMouseToFocus = "Meta+F5";
      kwin.view_actual_size = "Meta+0";
      kwin.view_zoom_in = ["Meta++" "Meta+="];
      kwin.view_zoom_out = "Meta+-";
      kwin.disableInputCapture = "Meta+Shift+Esc";

      # ========================================================================
      # System & Session
      # ========================================================================
      "KDE Keyboard Layout Switcher"."Switch to Last-Used Keyboard Layout" = "Meta+Alt+L";
      "KDE Keyboard Layout Switcher"."Switch to Next Keyboard Layout" = "Meta+Alt+K";
      ksmserver."Log Out" = "Ctrl+Alt+Del";
      
      # ========================================================================
      # Volume & Media
      # ========================================================================
      kmix.decrease_microphone_volume = "Microphone Volume Down";
      kmix.decrease_volume = "Volume Down";
      kmix.decrease_volume_small = "Shift+Volume Down";
      kmix.increase_microphone_volume = "Microphone Volume Up";
      kmix.increase_volume = "Volume Up";
      kmix.increase_volume_small = "Shift+Volume Up";
      kmix.mic_mute = ["Microphone Mute" "Meta+Volume Mute"];
      kmix.mute = "Volume Mute";
      
      mediacontrol.nextmedia = "Media Next";
      mediacontrol.pausemedia = "Media Pause";
      mediacontrol.playpausemedia = "Media Play";
      mediacontrol.previousmedia = "Media Previous";
      mediacontrol.stopmedia = "Media Stop";

      # ========================================================================
      # Power Management
      # ========================================================================
      org_kde_powerdevil."Decrease Keyboard Brightness" = "Keyboard Brightness Down";
      org_kde_powerdevil."Decrease Screen Brightness" = "Monitor Brightness Down";
      org_kde_powerdevil."Increase Keyboard Brightness" = "Keyboard Brightness Up";
      org_kde_powerdevil."Increase Screen Brightness" = "Monitor Brightness Up";
      org_kde_powerdevil.Hibernate = "Hibernate";
      org_kde_powerdevil.Sleep = "Sleep";
      org_kde_powerdevil."Toggle Keyboard Backlight" = "Keyboard Light On/Off";
      org_kde_powerdevil.powerProfile = ["Battery" "Meta+B"];

      # ========================================================================
      # Plasma Shell
      # ========================================================================
      plasmashell."activate application launcher" = "Alt+F1";
      plasmashell.clipboard_action = "Meta+Ctrl+X";
      plasmashell.cycle-panels = "Meta+Alt+P";
      plasmashell."manage activities" = "Meta+E";
      plasmashell."next activity" = "Meta+A";
      plasmashell."previous activity" = "Meta+Shift+A";
      plasmashell."show dashboard" = "Ctrl+F12";
      plasmashell.show-on-mouse-pos = "Meta+V";

      # Task Manager shortcuts (Meta+1..9)
      plasmashell."activate task manager entry 1" = "Meta+1";
      plasmashell."activate task manager entry 2" = "Meta+2";
      plasmashell."activate task manager entry 3" = "Meta+3";
      plasmashell."activate task manager entry 4" = "Meta+4";
      plasmashell."activate task manager entry 5" = "Meta+5";
      plasmashell."activate task manager entry 6" = "Meta+6";
      plasmashell."activate task manager entry 7" = "Meta+7";
      plasmashell."activate task manager entry 8" = "Meta+8";
      plasmashell."activate task manager entry 9" = "Meta+9";

      # ========================================================================
      # Application Shortcuts
      # ========================================================================
      "org.kde.dolphin.desktop"."_launch" = "Meta+Shift+Q";
      "org.kde.konsole.desktop"."_launch" = "Ctrl+Alt+T";
      "org.kde.krunner.desktop"."_launch" = "Alt+Space";
      "org.kde.plasma-systemmonitor.desktop"."_launch" = "Meta+Esc";
      "org.kde.plasma.emojier.desktop"."_launch" = "Meta+.";
      "org.kde.spectacle.desktop"."ActiveWindowScreenShot" = "Meta+Print";
      "org.kde.spectacle.desktop"."FullScreenScreenShot" = "Shift+Print";
      "org.kde.spectacle.desktop"."RecordRegion" = "Meta+R";
      "org.kde.spectacle.desktop"."RecordScreen" = "Meta+Alt+R";
      "org.kde.spectacle.desktop"."RecordWindow" = "Meta+Ctrl+R";
      "org.kde.spectacle.desktop"."RectangularRegionScreenShot" = "Meta+Shift+S";
      "org.kde.spectacle.desktop"."WindowUnderCursorScreenShot" = "Meta+Ctrl+Print";
      "org.kde.spectacle.desktop"."_launch" = "Print";
      "org.kde.touchpadshortcuts.desktop"."ToggleTouchpad" = "Touchpad Toggle";
    };

    # ==========================================================================
    # Config Files (settings without native options)
    # ==========================================================================
    configFile = {
      # ---- Mouse Input (no native option for specific device settings) ----
      "kcminputrc"."Libinput][1133][16511][Logitech G502" = {
        PointerAcceleration = "0";
        PointerAccelerationProfile = 1;
      };

      # ---- KWin Settings (no native equivalents) ----
      "kwinrc"."Windows" = {
        SeparateScreenFocus = true;
        ActiveMouseScreen = true;
      };

      "kwinrc"."ElectricBorders" = {
        TopLeft = 0;
        TopRight = 0;
        BottomLeft = 0;
        BottomRight = 0;
      };

      "plasmaparc"."General" = {
        showVirtualDevices = true;
      };

      "kwinrc"."TabBox" = {
        LayoutName = "compact";
      };

      "kwinrc"."Xwayland" = {
        Scale = 1;
      };

      # ---- KDE Globals ----
      "kdeglobals"."KDE" = {
        AnimationDurationFactor = "0.7071067811865475";  # 30% faster animations
        LookAndFeelPackage = "org.kde.breezedark.desktop";
      };

      "kdeglobals"."KFileDialog Settings" = {
        "Show hidden files" = true;
        "Sort directories first" = true;
      };

      # ---- Session Restore ----
      "ksmserverrc"."General" = {
        loginMode = "restorePreviousLogout";
        confirmLogout = true;
        shutdownType = 0;
        excludeApps = "";
      };

      # ---- Keyboard Layout & XKB Options ----
      "kxkbrc"."Layout" = {
        Options = "caps:super";
        ResetOldOptions = true;
        Use = true;
      };

      # ---- Launch Feedback ----
      "klaunchrc"."FeedbackStyle" = {
        BusyCursor = true;
      };

      # ---- Breeze Window Decoration ----
      "breezerc"."Windeco Exception 0" = {
        Enabled = true;
        ExceptionPattern = ".*";
        ExceptionType = 0;
        HideTitleBar = false;
        BorderSize = 1;
      };

      "breezerc"."Common" = {
        BorderSize = 3;
      };
      
      # ---- Baloo (File Indexing) ----
      "baloofilerc"."General" = {
        "first run" = false;
      };

      # ---- Timezone ----
      "ktimezonedrc"."TimeZones" = {
        LocalZone = "Europe/Berlin";
        ZoneinfoDir = "/etc/zoneinfo";
        Zonetab = "/etc/zoneinfo/zone.tab";
      };

      # ---- KDE Daemon ----
      "kded5rc"."Module-browserintegrationreminder" = {
        autoload = false;
      };

      # ---- Activity Manager ----
      "kactivitymanagerdrc"."Plugins" = {
        "org.kde.ActivityManager.ResourceScoringEnabled" = true;
      };

      # ---- Locale ----
      "plasma-localerc"."Formats" = {
        LANG = "en_US.UTF-8";
      };

      # ---- Konsole ----
      "konsolerc"."MainWindow" = {
        MenuBar = "Disabled";
        ToolBarsMovable = "Disabled";
      };
      
      "konsolerc"."TabBar" = {
        NewTabBehavior = "PutNewTabAfterCurrentTab";
      };
    };
  };

  # ============================================================================
  # KDE APPLICATIONS - Individual App Configurations
  # ============================================================================

  # Konsole (Terminal)
  programs.konsole = {
    enable = true;
    defaultProfile = "NixOS-Default";
    # ui.colorScheme = null;  # Use system theme
    
    profiles."NixOS-Default" = {
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 12;
      };
      
      extraConfig = {
        "Scrolling" = {
          HistoryMode = 2;  # Unlimited
        };
        "Terminal Features" = {
          BlinkingCursorEnabled = true;
        };
      };
    };
  };

  # Kate (Text Editor) - Disabled
  programs.kate = {
    enable = true;
    # package = pkgs.kdePackages.kate;
    # editor = {
    #   font = {
    #     family = "JetBrainsMono Nerd Font";
    #     pointSize = 11;
    #   };
    #   indent = {
    #     width = 2;
    #     replaceWithSpaces = true;
    #     showLines = true;
    #   };
    #   tabWidth = 2;
    #   inputMode = "normal";  # or "vi"
    #   brackets = {
    #     automaticallyAddClosing = true;
    #     highlightMatching = true;
    #   };
    # };
    # lsp.customServers = null;
    # dap.customServers = null;
  };

  # Okular (PDF Viewer) - Disabled
  programs.okular = {
    enable = true;
    # package = pkgs.kdePackages.okular;
    # general = {
    #   openFileInTabs = true;
    #   showScrollbars = true;
    #   smoothScrolling = true;
    #   viewContinuous = true;
    #   viewMode = "Single";  # "Single", "Facing", "FacingFirstCentered", "Summary"
    #   zoomMode = "fitWidth";  # "100%", "fitWidth", "fitPage", "autoFit"
    # };
  };

  # Elisa (Music Player) - Disabled
  programs.elisa = {
    enable = false;
    # package = pkgs.kdePackages.elisa;
    # appearance = {
    #   defaultView = "allAlbums";
    #   showNowPlayingBackground = true;
    # };
    # indexer = {
    #   scanAtStartup = true;
    #   paths = [ "$HOME/Music" ];
    # };
    # player = {
    #   minimiseToSystemTray = false;
    # };
  };

  # Ghostwriter (Markdown Editor) - Disabled
  programs.ghostwriter = {
    enable = false;
    # package = pkgs.kdePackages.ghostwriter;
    # editor = {
    #   styling = {
    #     focusMode = "sentence";
    #     editorWidth = "medium";
    #     useLargeHeadings = true;
    #   };
    # };
    # general = {
    #   fileSaving.autoSave = true;
    #   session.rememberRecentFiles = true;
    # };
    # spelling = {
    #   liveSpellCheck = true;
    #   checkerEnabledByDefault = true;
    # };
  };

  # ============================================================================
  # Notes on Settings NOT Manageable via plasma-manager:
  # - kwinoutputconfig.json (monitor VRR, HDR, color depth) - hardware-specific
  # - Per-screen wallpapers
  # ============================================================================
}

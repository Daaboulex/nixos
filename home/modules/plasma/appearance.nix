# Plasma Appearance & Session
# Workspace theme, KDE globals, window decorations, session restore
{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.plasma = {
    # ==========================================================================
    # Workspace Settings
    # ==========================================================================
    workspace = {
      clickItemTo = lib.mkDefault "select";
      lookAndFeel = lib.mkDefault "org.kde.breezedark.desktop";
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
    # Session Restore (native plasma-manager options)
    # ==========================================================================
    session = {
      general.askForConfirmationOnLogout = lib.mkDefault true;
      sessionRestore = {
        restoreOpenApplicationsOnLogin = lib.mkDefault "onLastLogout";
        excludeApplications = lib.mkDefault [ ];
      };
    };

    # ==========================================================================
    # Config Files — Appearance settings without native options
    # ==========================================================================
    configFile = {
      # ---- KDE Globals ----
      "kdeglobals"."KDE" = {
        AnimationDurationFactor = lib.mkDefault "0.7071067811865475"; # ~30% faster animations (sqrt(0.5))
        LookAndFeelPackage = lib.mkDefault "org.kde.breezedark.desktop";
      };

      "kdeglobals"."KFileDialog Settings" = {
        "Show hidden files" = lib.mkDefault true;
        "Sort directories first" = lib.mkDefault true;
      };

      # ---- Launch Feedback ----
      "klaunchrc"."FeedbackStyle" = {
        BusyCursor = lib.mkDefault true;
      };

      # ---- Breeze Window Decoration ----
      "breezerc"."Windeco Exception 0" = {
        Enabled = lib.mkDefault true;
        ExceptionPattern = lib.mkDefault ".*";
        ExceptionType = lib.mkDefault 0;
        HideTitleBar = lib.mkDefault false;
        BorderSize = lib.mkDefault 1;
      };

      "breezerc"."Common" = {
        BorderSize = lib.mkDefault 3;
      };

      # ---- Plasma PA (PulseAudio Volume Control) ----
      "plasmaparc"."General" = {
        showVirtualDevices = lib.mkDefault true;
      };
    };
  };
}

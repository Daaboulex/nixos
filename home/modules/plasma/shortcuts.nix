# Plasma Keyboard Shortcuts
# All keyboard shortcut bindings for KDE Plasma
{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.plasma = {
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
    # Keyboard Shortcuts
    # ==========================================================================
    shortcuts = {
      # ========================================================================
      # KWin Window Management (Core)
      # ========================================================================
      kwin."Activate Window Demanding Attention" = "Meta+Ctrl+A";
      kwin."Edit Tiles" = "Meta+T";
      kwin.Expose = "Ctrl+F9";
      kwin.ExposeAll = [
        "Ctrl+F10"
        "Launch (C)"
      ];
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
      kwin."Switch Window Down" = "";
      kwin."Switch Window Left" = "";
      kwin."Switch Window Right" = "";
      kwin."Switch Window Up" = "";

      # ---- Window Switching (Plasma defaults) ----
      kwin."Walk Through Windows" = "Alt+Tab";
      kwin."Walk Through Windows (Reverse)" = "Alt+Shift+Tab";
      kwin."Walk Through Windows of Current Application" = "Alt+\`";
      kwin."Walk Through Windows of Current Application (Reverse)" = "Alt+~";

      # ---- Quick Tile ----
      kwin."Window Quick Tile Bottom" = "Meta+Down";
      kwin."Window Quick Tile Left" = "Meta+Left";
      kwin."Window Quick Tile Right" = "Meta+Right";
      kwin."Window Quick Tile Top" = "Meta+Up";

      # ---- Fluid Tile Script Shortcuts ----
      kwin."Fluid tile | Toggle window to blocklist" = "Meta+F"; # Toggle active window tiling on/off
      kwin."Fluid tile | Change tile layout" = "Meta+Alt+F"; # Cycle through tile layouts

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
      kwin.view_zoom_in = [
        "Meta++"
        "Meta+="
      ];
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
      kmix.mic_mute = [
        "Microphone Mute"
        "Meta+Volume Mute"
      ];
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
      org_kde_powerdevil.powerProfile = [
        "Battery"
        "Meta+B"
      ];

      # ========================================================================
      # Plasma Shell
      # ========================================================================
      plasmashell."activate application launcher" = [
        "Meta"
        "Alt+F1"
      ];
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
  };
}

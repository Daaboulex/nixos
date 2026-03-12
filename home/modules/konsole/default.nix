{
  config,
  pkgs,
  lib,
  ...
}:

{
  # ============================================================================
  # Konsole (Terminal Emulator)
  # ============================================================================
  programs.konsole = {
    enable = true;
    defaultProfile = lib.mkDefault "NixOS-Default";

    profiles."NixOS-Default" = {
      font = {
        name = lib.mkDefault "JetBrainsMono Nerd Font";
        size = lib.mkDefault 12;
      };

      extraConfig = {
        "Scrolling" = {
          HistoryMode = lib.mkDefault 2; # Unlimited
        };
        "Terminal Features" = {
          BlinkingCursorEnabled = lib.mkDefault true;
        };
      };
    };
  };

  # ============================================================================
  # Konsole configFile — settings without native plasma-manager options
  # ============================================================================
  programs.plasma.configFile = {
    "konsolerc"."Desktop Entry" = {
      DefaultProfile = lib.mkDefault "NixOS-Default.profile";
    };

    "konsolerc"."MainWindow" = {
      MenuBar = lib.mkDefault "Disabled";
      ToolBarsMovable = lib.mkDefault "Disabled";
    };

    "konsolerc"."Notification Messages" = {
      CloseAllEmptyTabs = lib.mkDefault true; # Don't ask when closing empty tabs
      CloseAllTabs = lib.mkDefault true; # Don't ask when closing all tabs
    };

    "konsolerc"."TabBar" = {
      NewTabBehavior = lib.mkDefault "PutNewTabAfterCurrentTab";
    };
  };
}

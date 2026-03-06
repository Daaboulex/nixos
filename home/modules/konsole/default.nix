{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Konsole (Terminal Emulator)
  # ============================================================================
  programs.konsole = {
    enable = true;
    defaultProfile = "NixOS-Default";

    profiles."NixOS-Default" = {
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 12;
      };

      extraConfig = {
        "Scrolling" = {
          HistoryMode = 2; # Unlimited
        };
        "Terminal Features" = {
          BlinkingCursorEnabled = true;
        };
      };
    };
  };

  # Konsole window/tab settings (managed via plasma configFile)
  programs.plasma.configFile = {
    "konsolerc"."MainWindow" = {
      MenuBar = "Disabled";
      ToolBarsMovable = "Disabled";
    };
    "konsolerc"."TabBar" = {
      NewTabBehavior = "PutNewTabAfterCurrentTab";
    };
  };
}

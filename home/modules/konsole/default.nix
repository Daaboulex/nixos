# konsole — KDE terminal emulator with theme-derived colors and optional GPU acceleration.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:

let
  cfg = config.myModules.home.konsole;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c theme;
  themeFontFamily = theme.font.family;
in
{
  options.myModules.home.konsole = {
    enable = lib.mkEnableOption "Konsole KDE terminal emulator";
    gpuAcceleration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable experimental GPU-accelerated rendering and Kitty protocol.";
    };
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    # ============================================================================
    # Konsole (Terminal Emulator)
    # ============================================================================
    programs.konsole = myLib.mergeSettings {
      defaults = {
        enable = true;
        defaultProfile = lib.mkDefault "NixOS-Default";

        profiles."NixOS-Default" = {
          font = {
            name = lib.mkDefault (if hasTheme then themeFontFamily else "JetBrainsMono Nerd Font");
            size = lib.mkDefault 12;
          };

          colorScheme = lib.mkDefault (if hasTheme then "BreezeDark-Custom" else null);

          extraConfig = {
            "Appearance" = {
              LineSpacing = lib.mkDefault 1;
            };
            "Scrolling" = {
              HistoryMode = lib.mkDefault 2; # Unlimited
              ScrollBarPosition = lib.mkDefault 2; # Hidden
            };
            "Terminal Features" = {
              BlinkingCursorEnabled = lib.mkDefault true;
              FlowControlEnabled = lib.mkDefault false;
            }
            // lib.optionalAttrs cfg.gpuAcceleration {
              GraphicsEnabled = lib.mkDefault true; # Kitty/Sixel Graphics Protocol
              LowLatencyRendering = lib.mkDefault true; # Zero-latency typing
            };
          };
        };
      }
      // lib.optionalAttrs hasTheme {
        customColorSchemes."BreezeDark-Custom" = pkgs.writeText "BreezeDark-Custom.colorscheme" ''
          [Background]
          Color=${c.background-rgb}

          [BackgroundIntense]
          Color=${c.surface-rgb}

          [Color0]
          Color=${c.background-rgb}

          [Color0Intense]
          Color=${c.surface-rgb}

          [Color1]
          Color=${c.red-rgb}

          [Color1Intense]
          Color=${c.red-rgb}

          [Color2]
          Color=${c.green-rgb}

          [Color2Intense]
          Color=${c.green-rgb}

          [Color3]
          Color=${c.orange-rgb}

          [Color3Intense]
          Color=${c.orange-rgb}

          [Color4]
          Color=${c.blue-rgb}

          [Color4Intense]
          Color=${c.blue-rgb}

          [Color5]
          Color=${c.purple-rgb}

          [Color5Intense]
          Color=${c.purple-rgb}

          [Color6]
          Color=${c.blue-alt-rgb}

          [Color6Intense]
          Color=${c.blue-alt-rgb}

          [Color7]
          Color=${c.foreground-dim-rgb}

          [Color7Intense]
          Color=${c.foreground-rgb}

          [Foreground]
          Color=${c.foreground-rgb}

          [ForegroundIntense]
          Color=${c.foreground-rgb}

          [General]
          Description=BreezeDark-Custom
          Opacity=1
        '';
      };
      overrides = cfg.settings;
    };

    # ============================================================================
    # Konsole configFile — settings without native plasma-manager options
    # ============================================================================
    programs.plasma.configFile = {
      "konsolerc"."Desktop Entry" = {
        DefaultProfile = lib.mkDefault "NixOS-Default.profile";
      }
      // lib.optionalAttrs cfg.gpuAcceleration {
        RenderingMode = lib.mkDefault 1; # QtQuick (GPU-accelerated) renderer
      };

      "konsolerc"."MainWindow" = {
        MenuBar = lib.mkDefault "Disabled";
        ToolBarsMovable = lib.mkDefault "Disabled";
        StatusBar = lib.mkDefault "Disabled";
      };

      "konsolerc"."Notification Messages" = {
        CloseAllEmptyTabs = lib.mkDefault true; # Don't ask when closing empty tabs
        CloseAllTabs = lib.mkDefault true; # Don't ask when closing all tabs
      };

      "konsolerc"."TabBar" = {
        TabBarPosition = lib.mkDefault "Bottom";
        TabBarVisibility = lib.mkDefault "AlwaysShowTabBar";
        NewTabBehavior = lib.mkDefault "PutNewTabAfterCurrentTab";
      };
    };
  };
}

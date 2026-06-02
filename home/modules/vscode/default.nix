# vscode — VSCodium editor with theme-derived settings and font.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:

let
  cfg = config.myModules.home.vscode;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c theme;
  themeFontFamily = theme.font.family;
in
{
  options.myModules.home.vscode = {
    enable = lib.mkEnableOption "VSCodium editor";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    # ============================================================================
    # VSCodium - Open source VS Code
    # ============================================================================
    programs.vscodium = myLib.mergeSettings {
      defaults = {
        enable = true;

        profiles.default = {
          enableUpdateCheck = lib.mkDefault true;
          enableExtensionUpdateCheck = lib.mkDefault true;

          # Wrap the entire list in mkDefault
          extensions = lib.mkDefault (
            with pkgs.vscode-extensions;
            [
              jnoortheen.nix-ide
            ]
          );

          userSettings = lib.mkDefault (
            {
              # Telemetry
              "telemetry.telemetryLevel" = "off";
            }
            # Nix LSP only when the nil module provides the binary (guarded ref, AUDIT.md §19).
            // lib.optionalAttrs config.myModules.home.nil.enable {
              "nix.enableLanguageServer" = true;
              "nix.serverPath" = "nil";
            }
            // lib.optionalAttrs hasTheme {
              # Font from theme
              "editor.fontFamily" = "'${themeFontFamily}', 'Droid Sans Mono', monospace";
              "editor.fontSize" = 14;
              "terminal.integrated.fontFamily" = "'${themeFontFamily}'";

              # Built-in dark theme (syntax colors are well-tested)
              "workbench.colorTheme" = "Default Dark Modern";

              # Breeze Dark UI chrome — exact palette values for shell consistency
              "workbench.colorCustomizations" = {
                "editor.background" = c.background;
                "editor.foreground" = c.foreground;
                "editor.selectionBackground" = c.selection-alt;
                "editor.lineHighlightBackground" = c.surface;
                "editorCursor.foreground" = c.blue;
                "sideBar.background" = c.surface;
                "sideBar.foreground" = c.foreground;
                "sideBarTitle.foreground" = c.foreground;
                "activityBar.background" = c.background;
                "activityBar.foreground" = c.foreground;
                "titleBar.activeBackground" = c.surface;
                "titleBar.activeForeground" = c.foreground;
                "titleBar.inactiveBackground" = c.background;
                "statusBar.background" = c.surface;
                "statusBar.foreground" = c.foreground;
                "tab.activeBackground" = c.surface;
                "tab.activeForeground" = c.foreground;
                "tab.inactiveBackground" = c.background;
                "tab.inactiveForeground" = c.foreground-dim;
                "panel.background" = c.background;
                "panel.border" = c.surface-alt;
                "terminal.background" = c.background;
                "terminal.foreground" = c.foreground;
                "list.activeSelectionBackground" = c.selection-alt;
                "list.hoverBackground" = c.surface;
                "focusBorder" = c.blue;
                "input.background" = c.surface;
                "input.foreground" = c.foreground;
                "input.border" = c.surface-alt;
              };
            }
          );
        };
      };
      overrides = cfg.settings;
    };
  };
}

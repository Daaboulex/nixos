# appearance — Plasma workspace theme, KDE globals, window decorations, session restore.
{
  config,
  lib,
  myLib,
  ...
}:

let
  cfg = config.myModules.home.plasma.appearance;
in
{
  options.myModules.home.plasma.appearance = {
    enable = lib.mkEnableOption "Plasma appearance (colors, fonts, theme)";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    # Plasma lookAndFeel derived from myModules.home.theme when enabled.
    # Currently only breeze-dark palette exists; when more palettes are added,
    # the lookAndFeel can be derived from cfg.palette.
    programs.plasma = myLib.mergeSettings {
      defaults = {
        # ==========================================================================
        # Workspace Settings
        # ==========================================================================
        workspace = {
          clickItemTo = lib.mkDefault "select";
          # Derived from theme palette — currently only breeze-dark exists
          lookAndFeel = lib.mkDefault "org.kde.breezedark.desktop";
        };

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
          # LookAndFeelPackage handled by native workspace.lookAndFeel above
          "kdeglobals"."KDE" = {
            AnimationDurationFactor = lib.mkDefault "0.7071067811865475"; # ~30% faster animations (sqrt(0.5))
          };

          "kdeglobals"."KFileDialog Settings" = {
            "Show hidden files" = lib.mkDefault true;
            "Sort directories first" = lib.mkDefault true;
          };

          # ---- Default Terminal ----
          # Single source of truth: myModules.home.plasma.defaultTerminal (auto
          # ghostty > konsole, so the id can never dangle). Used by Dolphin/Kate
          # "Open Terminal", KRunner. Ctrl+Alt+T launch keybind is the sibling
          # kglobalshortcutsrc half in shortcuts.nix.
          "kdeglobals"."General" = lib.mkIf (config.myModules.home.plasma.defaultTerminal != null) (
            let
              term = config.myModules.home.plasma.defaultTerminal;
              termExec = lib.last (lib.splitString "." (lib.removeSuffix ".desktop" term));
            in
            {
              TerminalApplication = lib.mkDefault termExec;
              TerminalService = lib.mkDefault term;
            }
          );

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
      overrides = cfg.settings;
    };
  };
}

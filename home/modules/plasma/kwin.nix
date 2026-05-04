# kwin — Plasma KWin virtual desktops, tiling, night light, effects, and overrides.
{
  config,
  lib,
  myLib,
  ...
}:

let
  cfg = config.myModules.home.plasma.kwin;
in
{
  options.myModules.home.plasma.kwin = {
    enable = lib.mkEnableOption "KWin window manager settings";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    programs.plasma = myLib.mergeSettings {
      defaults = {
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
              latitude = "52.52"; # Berlin — override per-host if needed
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

          # Desktop effects — blur enabled for visual polish, translucency/contrast disabled
          "kwinrc"."Plugins"."blurEnabled" = lib.mkDefault true;
          "kwinrc"."Plugins"."contrastEnabled" = lib.mkDefault false;
          "kwinrc"."Plugins"."backgroundcontrastEnabled" = lib.mkDefault false;
          "kwinrc"."Plugins"."translucencyEnabled" = lib.mkDefault false;

          "kwinrc"."Effect-overview" = {
            BorderActivate = lib.mkDefault 9; # Disable hot corner
          };

          "kwinrc"."ElectricBorders" = {
            TopLeft = lib.mkDefault 0;
            TopRight = lib.mkDefault 0;
            BottomLeft = lib.mkDefault 0;
            BottomRight = lib.mkDefault 0;
          };

          "kwinrc"."TabBox" = {
            LayoutName = lib.mkDefault "org.kde.breeze.desktop";
          };

          "kwinrc"."Xwayland" = {
            Scale = lib.mkDefault 1;
          };

          "kwinrc"."ModifierOnlyShortcuts" = {
            Meta = lib.mkDefault "org.kde.plasmashell,/PlasmaShell,org.kde.PlasmaShell,activateLauncherMenu";
          };
        };
      };
      overrides = cfg.settings;
    };
  };
}

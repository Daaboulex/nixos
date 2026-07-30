# durdraw — terminal ANSI/ASCII art animation editor with theme-derived palette.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.durdraw;
  inherit (myLib.themeCtx { inherit config; }) hasTheme c;

  # Nearest xterm-256 color index from "R,G,B" string (6x6x6 cube)
  rgbTo256 =
    rgbStr:
    let
      parts = builtins.filter builtins.isString (builtins.split "," rgbStr);
      r = lib.toInt (builtins.elemAt parts 0);
      g = lib.toInt (builtins.elemAt parts 1);
      b = lib.toInt (builtins.elemAt parts 2);
    in
    16 + 36 * ((r + 25) / 51) + 6 * ((g + 25) / 51) + ((b + 25) / 51);

  # Generate ~/.durdraw/durdraw.ini from settings
  configFile = lib.generators.toINI { } cfg.settings;

  # Generate a .dtheme.ini file from theme attrs
  mkThemeFile =
    name: theme:
    let
      themeIni = lib.generators.toINI { } theme;
    in
    pkgs.writeText "${name}.dtheme.ini" themeIni;
in
{
  options.myModules.home.durdraw = {
    enable = lib.mkEnableOption "durdraw terminal art editor";

    settings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = { };
      example = lib.literalExpression ''
        {
          Main = {
            color-mode = "256";
          };
          Theme = {
            theme-256 = "~/.durdraw/mytheme.dtheme.ini";
          };
        }
      '';
      description = ''
        INI sections for ~/.durdraw/durdraw.ini.
        Each key is a section name, each value is an attrset of key-value pairs.
      '';
    };

    theme = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.attrsOf (lib.types.attrsOf (lib.types.either lib.types.str lib.types.int))
      );
      default = null;
      example = lib.literalExpression ''
        {
          Theme-256 = {
            name = "My Custom Theme";
            mainColor = 104;
            clickColor = 37;
            borderColor = 236;
            clickHighlightColor = 15;
            notificationColor = 87;
            promptColor = 189;
            menuItemColor = 189;
            menuTitleColor = 159;
            menuBorderColor = 24;
          };
        }
      '';
      description = ''
        Custom durdraw theme definition. When set, generates a .dtheme.ini
        file and wires it into the config. Sections are Theme-256 and/or Theme-16.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "--256color"
        "--blackbg"
      ];
      description = "Extra arguments passed to durdraw via a wrapper.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages =
          let
            basePkg = pkgs.durdraw;
            wrappedPkg =
              if cfg.extraArgs != [ ] then
                pkgs.symlinkJoin {
                  name = "durdraw-wrapped";
                  paths = [ basePkg ];
                  nativeBuildInputs = [ pkgs.makeWrapper ];
                  postBuild = ''
                    for bin in durdraw durview durfetch; do
                      if [ -f "$out/bin/$bin" ] || [ -L "$out/bin/$bin" ]; then
                        wrapProgram "$out/bin/$bin" \
                          --add-flags "${lib.escapeShellArgs cfg.extraArgs}"
                      fi
                    done
                  '';
                }
              else
                basePkg;
          in
          [ wrappedPkg ];

        # Generate ~/.durdraw/durdraw.ini when settings are non-empty
        home.file = lib.mkMerge [
          (lib.mkIf (cfg.settings != { }) {
            ".durdraw/durdraw.ini".text = configFile;
          })
          (lib.mkIf (cfg.theme != null) {
            ".durdraw/custom.dtheme.ini".source = mkThemeFile "custom" cfg.theme;
          })
        ];
      }
      # Breeze Dark 256-color theme defaults
      (lib.mkIf hasTheme {
        myModules.home.durdraw = {
          settings = {
            Main.color-mode = lib.mkDefault "256";
            Theme.theme-256 = lib.mkDefault "~/.durdraw/custom.dtheme.ini";
          };
          theme = lib.mkDefault {
            Theme-256 = {
              name = "Breeze Dark";
              mainColor = rgbTo256 c.blue-rgb;
              clickColor = rgbTo256 c.green-rgb;
              borderColor = rgbTo256 c.surface-rgb;
              clickHighlightColor = rgbTo256 c.foreground-rgb;
              notificationColor = rgbTo256 c.orange-rgb;
              promptColor = rgbTo256 c.blue-rgb;
              menuItemColor = rgbTo256 c.foreground-dim-rgb;
              menuTitleColor = rgbTo256 c.blue-rgb;
              menuBorderColor = rgbTo256 c.surface-rgb;
            };
          };
        };
      })
    ]
  );
}

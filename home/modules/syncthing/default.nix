# syncthing - writes per-folder .stignore files from declarative ignore patterns.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.syncthing;
in
{
  options.myModules.home.syncthing = {
    enable = lib.mkEnableOption "Syncthing folder sync configuration";

    folders = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              description = "Absolute path to sync.";
            };
            ignorePatterns = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Patterns to exclude from sync (Syncthing .stignore format).";
            };
          };
        }
      );
      default = { };
      description = "Folders to write a Syncthing .stignore for.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = lib.mapAttrs' (
      _name: folder:
      lib.nameValuePair "${lib.removePrefix "/home/${config.home.username}/" folder.path}/.stignore" {
        text = lib.concatStringsSep "\n" (folder.ignorePatterns ++ [ "" ]);
      }
    ) (lib.filterAttrs (_: f: f.ignorePatterns != [ ]) cfg.folders);

    home.packages = [
      pkgs.syncthing
      pkgs.syncthingtray
    ];

    xdg.configFile."autostart/syncthingtray.desktop".text = ''
      [Desktop Entry]
      Name=Syncthing Tray
      Exec=syncthingtray
      Type=Application
      X-KDE-autostart-phase=2
      X-KDE-StartupNotify=false
    '';
  };
}

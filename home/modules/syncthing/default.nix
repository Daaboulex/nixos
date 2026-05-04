# syncthing — Syncthing folder sync configuration with declarative folders and peer devices.
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
              description = "Absolute path to sync";
            };
            ignorePatterns = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Patterns to exclude from sync (Syncthing .stignore format)";
            };
            versioning = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable staggered file versioning (30-day retention)";
            };
          };
        }
      );
      default = { };
      description = "Folders to sync via Syncthing";
    };

    devices = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "ryzen-9950x3d" = "AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG-HHHHHHH";
      };
      description = "Map of device names to Syncthing device IDs";
    };

    peerDevices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Device names (from devices) to share all folders with";
    };
  };

  config = lib.mkIf cfg.enable {
    # Write .stignore files for each folder
    home.file = lib.mapAttrs' (
      _name: folder:
      lib.nameValuePair "${lib.removePrefix "/home/${config.home.username}/" folder.path}/.stignore" {
        text = lib.concatStringsSep "\n" (
          [
            "// Syncthing ignore patterns — managed by Home Manager"
            "// Do not edit manually"
          ]
          ++ folder.ignorePatterns
          ++ [ "" ]
        );
      }
    ) (lib.filterAttrs (_: f: f.ignorePatterns != [ ]) cfg.folders);

    home.packages = [
      pkgs.syncthing
      pkgs.syncthingtray # System tray + Dolphin/Plasma integration
    ];

    # Autostart tray icon with KDE
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

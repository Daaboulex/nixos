# syncthing — Syncthing continuous file synchronization across devices.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.services.syncthing;
      user = config.myModules.primaryUser or "user";
    in
    {
      _class = "nixos";
      options.myModules.services.syncthing = {
        enable = lib.mkEnableOption "Syncthing continuous file synchronization";

        startDelay = lib.mkOption {
          type = lib.types.ints.unsigned;
          default = 0;
          example = 120;
          description = ''
            Seconds to delay the syncthing daemon after login. On slow SSDs
            (DRAM-less, SATA), the initial full-folder scan after boot can
            saturate the I/O queue and freeze the UI. A delay lets the desktop
            session settle first. 0 = start immediately (default).
          '';
        };

        devices = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                id = lib.mkOption {
                  type = lib.types.str;
                  description = "Syncthing device ID";
                };
              };
            }
          );
          default = { };
          description = "Peer devices to sync with";
        };

        folders = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                path = lib.mkOption {
                  type = lib.types.str;
                  description = "Absolute path to sync";
                };
                devices = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  description = "Device names to share this folder with";
                };
                versioning = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Enable staggered file versioning";
                };
                versioningMaxAge = lib.mkOption {
                  type = lib.types.str;
                  default = "2592000";
                  description = "Maximum age of versioned files in seconds (default: 2592000 = 30 days)";
                };
                ignorePerms = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Ignore file permission changes (useful for folders synced across different environments)";
                };
                rescanIntervalS = lib.mkOption {
                  type = lib.types.ints.unsigned;
                  default = 3600;
                  example = 21600;
                  description = ''
                    Full-folder rescan interval in seconds. `fsWatcher` handles
                    real-time updates; this is the periodic safety scan. Raise
                    on large folders (huge Documents tree) to reduce metadata
                    I/O churn on slow SSDs. Default 3600 (1h); 21600 = 6h.
                  '';
                };
              };
            }
          );
          default = { };
          description = "Folders to sync";
        };
      };

      config = lib.mkIf cfg.enable {
        services.syncthing = {
          enable = true;
          inherit user;
          dataDir = "/home/${user}";
          configDir = "/home/${user}/.config/syncthing";
          openDefaultPorts = true;
          overrideDevices = true;
          overrideFolders = true;

          settings = {
            devices = lib.mapAttrs (_: dev: { inherit (dev) id; }) cfg.devices;

            folders = lib.mapAttrs (_: folder: {
              inherit (folder)
                path
                devices
                ignorePerms
                rescanIntervalS
                ;
              versioning = lib.mkIf folder.versioning {
                type = "staggered";
                params.maxAge = folder.versioningMaxAge;
              };
            }) cfg.folders;

            options = {
              urAccepted = -1; # Disable usage reporting
              relaysEnabled = false; # LAN only — no relay servers
              globalAnnounceEnabled = false; # LAN only — no global discovery
              localAnnounceEnabled = true; # Find peers on local network
            };
          };
        };

        # Optional post-login start delay — reduces post-boot I/O storm on
        # slow SSDs. Upstream NixOS syncthing sets TimeoutStartSec=15s, so
        # we MUST also bump the timeout or the ExecStartPre sleep triggers
        # a restart loop (service killed at 15 s, respawned, killed again).
        # TimeoutStartSec = startDelay + 60 s buffer for actual startup work.
        systemd.services.syncthing = lib.mkIf (cfg.startDelay > 0) {
          serviceConfig = {
            ExecStartPre = [
              "${pkgs.coreutils}/bin/sleep ${toString cfg.startDelay}"
            ];
            # Why: upstream NixOS syncthing sets TimeoutStartSec=15s. With
            # a 120 s ExecStartPre sleep this caused a restart loop —
            # must bump timeout past the sleep + normal startup budget.
            TimeoutStartSec = lib.mkForce (toString (cfg.startDelay + 60));
          };
        };
      };
    };
in
{
  flake.modules.nixos.services-syncthing = mod;

}

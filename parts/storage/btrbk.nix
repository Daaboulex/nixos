# btrbk — incremental btrfs snapshot replication to secondary drive.
#
# Sends read-only snapshots of live subvolumes to a target btrfs
# filesystem on a second drive, via `btrfs send | btrfs receive`.
# Not RAID: separate failure domain, corruption doesn't propagate
# instantly, retention history lets you roll back hours/days back.
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
      cfg = config.myModules.storage.btrbk;
    in
    {
      _class = "nixos";
      options.myModules.storage.btrbk = {
        enable = lib.mkEnableOption "btrbk incremental btrfs snapshot replication";

        sourcePath = lib.mkOption {
          type = lib.types.str;
          default = "/";
          description = ''
            Mount point of the source btrfs filesystem. Usually "/".
            btrbk will snapshot subvolumes accessible from here.
          '';
        };

        targetPath = lib.mkOption {
          type = lib.types.str;
          example = "/mnt/backup";
          description = ''
            Mount point of the target btrfs filesystem on the second drive.
            Must be a btrfs filesystem. Snapshots land in this directory.
          '';
        };

        subvolumes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "@"
            "@home"
            "@nix"
            "@log"
          ];
          description = ''
            Subvolume names to replicate. Default covers root + home +
            nix store + logs. Skip @cache / @tmp / @snapshots (regenerable
            or meta).
          '';
        };

        timer = lib.mkOption {
          type = lib.types.str;
          default = "hourly";
          example = "*:0/30";
          description = ''
            systemd OnCalendar spec for the replication timer. Default
            hourly. Finer cadence (e.g. *:0/30 = every 30 min) is fine;
            incremental sends are cheap.
          '';
        };

        snapshotPreserve = lib.mkOption {
          type = lib.types.str;
          default = "24h 14d 8w 6m";
          description = ''
            Retention on the SOURCE side (how many short-lived snapshots
            kept live on the root filesystem while btrbk runs). Syntax:
            "24h 14d 8w 6m" = hourly × 24, daily × 14, weekly × 8, monthly × 6.
          '';
        };

        targetPreserve = lib.mkOption {
          type = lib.types.str;
          default = "48h 30d 12w 12m";
          description = ''
            Retention on the TARGET drive. Longer history here — target
            exists precisely to hold deep backup history.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        services.btrbk = {
          instances.default = {
            onCalendar = cfg.timer;
            settings = {
              timestamp_format = "long";
              snapshot_preserve_min = "2h";
              snapshot_preserve = cfg.snapshotPreserve;
              target_preserve_min = "no";
              target_preserve = cfg.targetPreserve;
              # Why: default /var/log/btrbk.log is owned by root; the
              # btrbk systemd service drops to uid btrbk which cannot
              # write there → "Permission denied" every run. journald
              # already captures full stdout/stderr, so skip the file.
              volume."${cfg.sourcePath}" = {
                snapshot_dir = ".snapshots/btrbk";
                subvolume = lib.listToAttrs (
                  map (sv: {
                    name = sv;
                    value = {
                      target = "${cfg.targetPath}/${sv}";
                    };
                  }) cfg.subvolumes
                );
              };
            };
          };
        };

        # Ensure snapshot source dir + per-subvol target dirs exist.
        # Why: btrbk checks each `target = <dir>/<sv>` with `readlink -e`
        # before send; missing target dir = "Failed to fetch subvolume
        # detail" and the whole run aborts with exit 10. Creating the
        # parent directories lets btrbk `btrfs receive` the initial
        # full send into them.
        systemd.tmpfiles.rules = [
          "d ${cfg.sourcePath}/.snapshots/btrbk 0700 root root -"
        ]
        ++ map (sv: "d ${cfg.targetPath}/${sv} 0755 root root -") cfg.subvolumes;

        # btrbk CLI + tools for manual inspection
        environment.systemPackages = [ pkgs.btrbk ];

        assertions = [
          {
            assertion = cfg.targetPath != cfg.sourcePath;
            message = "myModules.storage.btrbk: targetPath must differ from sourcePath (replication requires separate filesystem)";
          }
        ];
      };
    };
in
{
  flake.modules.nixos.storage-btrbk = mod;
}

# btrbk — incremental btrfs snapshot replication to secondary drive.
#
# Sends read-only snapshots of live subvolumes to a target btrfs
# filesystem on a second drive, via `btrfs send | btrfs receive`.
# Not RAID: separate failure domain, corruption doesn't propagate
# instantly, retention history lets you roll back hours/days back.
#
# The module owns the whole backup domain: source snapshotting and
# replication (btrbk), the target drive's LUKS unlock + mount + keyfile
# permissions (targetDrive), the top-level source anchor mount
# (sourceAnchorDevice), target scrub, and the verified restore path
# (the btrbk-restore command). Hosts only parameterize.
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

      # Verified restore: every source snapshot must prove itself complete
      # (read-only; on the target additionally a Received UUID, which an
      # interrupted `btrfs receive` never stamps) before it can be staged.
      # The swap keeps the replaced subvolume as <name>.pre-restore-<stamp>;
      # the tool never deletes live data, so a restore cannot lose state.
      restoreTool = pkgs.writeShellApplication {
        name = "btrbk-restore";
        runtimeInputs = [
          pkgs.btrfs-progs
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnugrep
          pkgs.gnused
          pkgs.gawk
        ];
        text = ''
          SRC='${cfg.sourcePath}'
          TGT='${cfg.targetPath}'
          SNAPDIR="$SRC/.snapshots/btrbk"
          SUBVOLS=(${lib.concatMapStringsSep " " (sv: "'${sv}'") cfg.subvolumes})

          usage() {
            cat <<EOF
          btrbk-restore -- verified restore from btrbk snapshots. Never deletes:
          the replaced subvolume is kept as <subvol>.pre-restore-<stamp>.

            btrbk-restore list                       snapshots per subvolume (L=local, T=target)
            btrbk-restore verify  <subvol> <stamp>   prove a snapshot is complete and read-only
            btrbk-restore restore <subvol> <stamp>   stage, confirm on the TTY, then swap

            <subvol>  one of: ''${SUBVOLS[*]}
            <stamp>   btrbk timestamp, e.g. 20260709T0600
          EOF
            exit 64
          }

          die() {
            echo "ERROR: $*" >&2
            exit 1
          }

          is_ro() {
            p=$(btrfs property get -ts "$1" ro 2>/dev/null) && [ "$p" = "ro=true" ]
          }

          received_ok() {
            out=$(btrfs subvolume show "$1" 2>/dev/null) || return 1
            ruuid=$(sed -n 's/^[[:space:]]*Received UUID:[[:space:]]*//p' <<<"$out")
            [ -n "$ruuid" ] && [ "$ruuid" != "-" ]
          }

          check_subvol_arg() {
            for s in "''${SUBVOLS[@]}"; do
              [ "$s" = "$1" ] && return 0
            done
            die "unknown subvolume '$1' (expected one of: ''${SUBVOLS[*]})"
          }

          check_stamp_arg() {
            grep -qE '^[0-9]{8}T[0-9]{4}$' <<<"$1" \
              || die "bad timestamp '$1' (expected e.g. 20260709T0600)"
          }

          cmd_list() {
            for sv in "''${SUBVOLS[@]}"; do
              echo "== $sv"
              {
                if [ -d "$TGT/$sv" ]; then
                  find "$TGT/$sv" -mindepth 1 -maxdepth 1 -name "$sv.*" -printf '%f\n'
                fi
                if [ -d "$SNAPDIR" ]; then
                  find "$SNAPDIR" -mindepth 1 -maxdepth 1 -name "$sv.*" -printf '%f\n'
                fi
              } | sed "s/^$sv\.//" | sort -u | while read -r ts; do
                marks=""
                [ -d "$SNAPDIR/$sv.$ts" ] && marks="''${marks}L"
                [ -d "$TGT/$sv/$sv.$ts" ] && marks="''${marks}T"
                printf '  %s  [%s]\n' "$ts" "$marks"
              done
            done
          }

          cmd_verify() {
            sv=$1
            ts=$2
            local_snap="$SNAPDIR/$sv.$ts"
            tgt_snap="$TGT/$sv/$sv.$ts"
            ok=1
            if [ -d "$local_snap" ]; then
              if is_ro "$local_snap"; then
                echo "PASS local   $local_snap (read-only)"
              else
                echo "FAIL local   $local_snap is writable"
                ok=0
              fi
            else
              echo "none local   $local_snap"
            fi
            if [ -d "$tgt_snap" ]; then
              if ! is_ro "$tgt_snap"; then
                echo "FAIL target  $tgt_snap is writable"
                ok=0
              elif ! received_ok "$tgt_snap"; then
                echo "FAIL target  $tgt_snap has no Received UUID (interrupted receive -- garbled)"
                ok=0
              else
                echo "PASS target  $tgt_snap (read-only, receive completed)"
              fi
            else
              echo "none target  $tgt_snap"
            fi
            [ -d "$local_snap" ] || [ -d "$tgt_snap" ] || die "snapshot $sv.$ts exists nowhere"
            [ "$ok" = 1 ] || exit 1
          }

          cmd_restore() {
            sv=$1
            ts=$2
            stamp=$(date +%Y%m%dT%H%M%S)
            # A second restore in the same second, or a kept pre-restore dir
            # from an earlier pass, must get a fresh name -- every kept state
            # stays, none is ever refused into overwriting another.
            n=0
            suffix=""
            while [ -e "$SRC/$sv.staged-$stamp$suffix" ] || [ -e "$SRC/$sv.pre-restore-$stamp$suffix" ]; do
              n=$((n + 1))
              suffix="-$n"
            done
            stamp="$stamp$suffix"
            staged="$SRC/$sv.staged-$stamp"
            keep="$SRC/$sv.pre-restore-$stamp"
            [ -t 0 ] || die "restore needs an interactive TTY for confirmation"
            [ -d "$SRC/$sv" ] || die "live subvolume $SRC/$sv not found (is $SRC mounted?)"
            [ -e "$staged" ] && die "staging path $staged already exists"
            [ -e "$keep" ] && die "keep path $keep already exists"

            local_snap="$SNAPDIR/$sv.$ts"
            tgt_snap="$TGT/$sv/$sv.$ts"
            if [ -d "$local_snap" ]; then
              is_ro "$local_snap" || die "local snapshot $local_snap is writable -- refusing"
              echo "Staging from local snapshot $local_snap (instant, shares extents)."
              btrfs subvolume snapshot "$local_snap" "$staged" >/dev/null
            elif [ -d "$tgt_snap" ]; then
              is_ro "$tgt_snap" || die "target snapshot $tgt_snap is writable -- refusing"
              received_ok "$tgt_snap" \
                || die "target snapshot $tgt_snap has no Received UUID (interrupted receive) -- refusing"
              need=$(btrfs filesystem du -s --raw "$tgt_snap" | awk 'NR==2 {print $1}')
              [ "$need" -gt 0 ] 2>/dev/null || die "could not size $tgt_snap"
              avail=$(df --output=avail -B1 "$SRC" | tail -1 | tr -d ' ')
              [ "$avail" -gt $((need + need / 10)) ] \
                || die "not enough space on $SRC: need ~$need bytes (+10%), have $avail"
              incoming="$SRC/.restore-incoming"
              [ -e "$incoming/$sv.$ts" ] \
                && die "leftover $incoming/$sv.$ts from an earlier attempt -- inspect and delete it first"
              mkdir -p "$incoming"
              echo "Receiving $tgt_snap -> $incoming (full transfer, may take a while)..."
              btrfs send "$tgt_snap" | btrfs receive "$incoming"
              received_ok "$incoming/$sv.$ts" \
                || die "receive did not complete cleanly -- staging aborted, live subvolume untouched"
              btrfs subvolume snapshot "$incoming/$sv.$ts" "$staged" >/dev/null
              btrfs subvolume delete "$incoming/$sv.$ts" >/dev/null
              rmdir "$incoming"
            else
              die "snapshot $sv.$ts found neither at $local_snap nor $tgt_snap (see btrbk-restore list)"
            fi

            cat <<EOF

          About to swap in the restored subvolume:
            1. mv $SRC/$sv -> $keep   (current state KEPT, nothing deleted)
            2. mv $staged -> $SRC/$sv
          Then REBOOT so every mount picks up the restored subvolume.
          Rollback (before cleanup): mv $SRC/$sv $SRC/$sv.rejected-$stamp && mv $keep $SRC/$sv
          Cleanup (only after the restore is verified good): btrfs subvolume delete $keep

          EOF
            printf 'Type "restore" to proceed: '
            read -r answer || answer=""
            if [ "$answer" != "restore" ]; then
              btrfs subvolume delete "$staged" >/dev/null
              die "aborted -- staged copy removed, live subvolume untouched"
            fi
            mv "$SRC/$sv" "$keep"
            mv "$staged" "$SRC/$sv"
            sync
            echo "Swapped: $sv is now $sv.$ts; previous state kept at $keep."
            echo "Reboot now."
          }

          [ "$(id -u)" = 0 ] || die "must run as root"
          [ $# -ge 1 ] || usage
          command=$1
          shift
          case "$command" in
            list)
              [ $# -eq 0 ] || usage
              cmd_list
              ;;
            verify)
              [ $# -eq 2 ] || usage
              check_subvol_arg "$1"
              check_stamp_arg "$2"
              cmd_verify "$1" "$2"
              ;;
            restore)
              [ $# -eq 2 ] || usage
              check_subvol_arg "$1"
              check_stamp_arg "$2"
              cmd_restore "$1" "$2"
              ;;
            *)
              usage
              ;;
          esac
        '';
      };
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

        sourceAnchorDevice = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "/dev/mapper/cryptroot";
          description = ''
            When set, the module mounts this device's btrfs TOP LEVEL
            (subvolid=5) at sourcePath. btrbk's volume directive needs the
            subvolumes reachable as <sourcePath>/@, <sourcePath>/@home; a
            production layout that mounts @ AS / does not provide that.
            null = sourcePath is already such a mount.
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

        targetDrive = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options = {
                luksUuid = lib.mkOption {
                  type = lib.types.strMatching "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}";
                  description = "LUKS partition UUID of the backup drive.";
                };
                keyFile = lib.mkOption {
                  type = lib.types.str;
                  example = "/etc/secrets/backup.key";
                  description = ''
                    LUKS keyfile path. Must live on an encrypted filesystem
                    that is unlocked BEFORE this drive (e.g. the root fs) --
                    never in the initrd, which is copied to unencrypted /boot.
                  '';
                };
                mountOptions = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [
                    "compress=zstd:3"
                    "noatime"
                    "ssd"
                    "discard=async"
                    # Backup data is re-sendable: a longer commit interval
                    # trades a bigger loss window for fewer metadata flushes
                    # (DRAM-less SSDs choke on frequent metadata commits).
                    "commit=120"
                    "nofail"
                    "x-systemd.device-timeout=30s"
                  ];
                  description = "Mount options for the target filesystem.";
                };
              };
            }
          );
          default = null;
          description = ''
            LUKS-encrypted dedicated backup drive owned by this module:
            crypttab unlock (post-root, as "cryptbackup"), mount at
            targetPath, keyfile permission enforcement, and a scrub of the
            target filesystem. null = the host provides the target mount.
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
            or meta). Churn directories inside a replicated subvolume
            (caches, trash) are excluded by making them NESTED subvolumes:
            btrfs snapshots never descend into a nested subvolume.
          '';
        };

        timer = lib.mkOption {
          type = lib.types.str;
          default = "hourly";
          example = "*:0/30";
          description = ''
            systemd OnCalendar spec for the replication timer.
          '';
        };

        snapshotPreserve = lib.mkOption {
          type = lib.types.str;
          default = "24h 14d 8w 6m";
          description = ''
            Retention on the SOURCE side (how many short-lived snapshots
            kept live on the root filesystem while btrbk runs). Syntax:
            "24h 14d 8w 6m" = hourly x 24, daily x 14, weekly x 8, monthly x 6.
            MUST cover more than the send cadence (timer), or the parent
            snapshot each incremental send needs gets pruned and every
            send degrades to a full transfer.
          '';
        };

        targetPreserve = lib.mkOption {
          type = lib.types.str;
          default = "48h 30d 12w 12m";
          description = ''
            Retention on the TARGET drive. Longer history here -- target
            exists precisely to hold deep backup history. Size it against
            the drive: history that fills the disk stalls every receive.
          '';
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            services.btrbk = {
              # Upstream's own knob for the send/receive IO class; a raw
              # serviceConfig.IOSchedulingClass would conflict with it.
              ioSchedulingClass = "idle";
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

            # Replication is a background job -- keep it invisible to
            # foreground work and out of the way of real memory pressure:
            # idle CPU/IO classes (bfq and mq-deadline honor the IO class;
            # kernel-side btrfs workers are outside it; the sudo'd btrfs
            # send/receive children inherit both); MemoryHigh reclaim-
            # throttles a pathological run instead of pushing the desktop
            # into swap; ConditionMemoryPressure skips a run outright while
            # memory is already thrashing -- the next timer slot retries.
            # IO pressure is deliberately NOT a condition: PSI io reads
            # high on idle disks under sched_ext, so gating on it would
            # silently stop backups.
            systemd.services."btrbk-default" = {
              unitConfig.ConditionMemoryPressure = "60%";
              serviceConfig = {
                CPUSchedulingPolicy = "idle";
                MemoryHigh = "1G";
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

            # btrbk CLI for manual inspection + the verified restore path.
            environment.systemPackages = [
              pkgs.btrbk
              restoreTool
            ];

            assertions = [
              {
                assertion = cfg.targetPath != cfg.sourcePath;
                message = "myModules.storage.btrbk: targetPath must differ from sourcePath (replication requires separate filesystem)";
              }
              {
                assertion = cfg.subvolumes != [ ] && builtins.all (sv: !lib.hasInfix "/" sv) cfg.subvolumes;
                message = "myModules.storage.btrbk: subvolumes must be a non-empty list of top-level subvolume names (no '/')";
              }
              {
                # btrbk needs btrfs on both ends (btrfs send | btrfs receive).
                # The btrfs default means a non-mount-point path (e.g. an
                # auto-mounted or sub-directory target) never false-fails;
                # only a path that IS a declared non-btrfs mount is caught.
                assertion = (config.fileSystems.${cfg.sourcePath} or { fsType = "btrfs"; }).fsType == "btrfs";
                message = "myModules.storage.btrbk: sourcePath ${cfg.sourcePath} is a declared non-btrfs filesystem; btrbk requires btrfs (btrfs send|receive)";
              }
              {
                assertion = (config.fileSystems.${cfg.targetPath} or { fsType = "btrfs"; }).fsType == "btrfs";
                message = "myModules.storage.btrbk: targetPath ${cfg.targetPath} is a declared non-btrfs filesystem; btrbk requires btrfs (btrfs send|receive)";
              }
            ];
          }

          (lib.mkIf (cfg.targetDrive != null) {
            # Post-root LUKS unlock via the systemd-cryptsetup generator.
            # 'nofail' = don't block boot if the drive is missing. 'discard'
            # = SSD TRIM through dm-crypt. Not initrd: the keyfile must stay
            # on the encrypted root (see the keyFile option).
            environment.etc.crypttab.text = ''
              cryptbackup  UUID=${cfg.targetDrive.luksUuid}  ${cfg.targetDrive.keyFile}  luks,discard,nofail,no-read-workqueue,no-write-workqueue
            '';

            fileSystems."${cfg.targetPath}" = {
              device = "/dev/mapper/cryptbackup";
              fsType = "btrfs";
              options = cfg.targetDrive.mountOptions;
            };

            # Enforce keyfile permissions declaratively -- prevents drift if
            # someone later does `chmod 444` etc. tmpfiles 'z' fixes mode +
            # ownership on every boot without re-creating the file.
            systemd.tmpfiles.rules = [
              "d ${dirOf cfg.targetDrive.keyFile} 0700 root root -"
              "z ${cfg.targetDrive.keyFile} 0400 root root -"
            ];

            # Scrub the backup filesystem: detects silent bit-rot on the
            # target before it corrupts received snapshots. The host owns
            # services.btrfs.autoScrub.interval (one global cadence).
            services.btrfs.autoScrub = {
              enable = true;
              fileSystems = [ cfg.targetPath ];
            };
          })

          (lib.mkIf (cfg.sourceAnchorDevice != null) {
            # Top-level btrfs mount on the source device (see the
            # sourceAnchorDevice option). subvolid is stable -- unlike
            # subvol=/, which is accepted but not documented to always map
            # to subvolid=5. Admin-only view: nothing executes from it.
            fileSystems."${cfg.sourcePath}" = {
              device = cfg.sourceAnchorDevice;
              fsType = "btrfs";
              options = [
                "subvolid=5"
                # Match the per-subvol zstd:1 so re-reads aren't recompressed.
                "compress=zstd:1"
                "noatime"
                "ssd"
                "discard=async"
                "nosuid"
                "nodev"
                "noexec"
              ];
            };
          })
        ]
      );
    };
in
{
  flake.modules.nixos.storage-btrbk = mod;

}

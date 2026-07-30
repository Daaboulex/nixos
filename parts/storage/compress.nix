# storage-compress — periodic btrfs recompression (defrag -czstd) of btrfs
# subvolumes. Apps preallocate installs with fallocate so the compress= mount
# option never fires on write; this idle-priority pass is the wired
# recompression, skipped per-subvolume via the generation counter when nothing
# changed. Defrag is CoW + checksummed, so a concurrent read/write or power loss
# never corrupts (worst case wasted work); no in-use gate is needed.
_:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.storage.compress;
      script = pkgs.writeShellApplication {
        name = "storage-compress";
        runtimeInputs = with pkgs; [
          btrfs-progs
          compsize
          coreutils
          findutils
          gawk
          systemd
        ];
        text = ''
          subvols=(${lib.escapeShellArgs cfg.subvolumes})
          level=${toString cfg.level}
          for sv in "''${subvols[@]}"; do
            if [ ! -d "$sv" ]; then
              echo "storage-compress: $sv missing, skipped"
              continue
            fi
            gen=$(btrfs subvolume show "$sv" 2>/dev/null | awk '$1 == "Generation:" { print $2; exit }' || true)
            if [ -z "$gen" ]; then
              echo "storage-compress: $sv is not a btrfs subvolume, skipped"
              continue
            fi
            state="$STATE_DIRECTORY/$(systemd-escape -- "$sv")"
            last=$(cat "$state" 2>/dev/null || true)
            if [ "$gen" = "$last" ]; then
              echo "storage-compress: $sv unchanged at generation $gen, skipped"
              continue
            fi
            btrfs property set "$sv" compression zstd
            echo "storage-compress: before $sv"
            compsize -x "$sv" || echo "storage-compress: compsize failed on $sv"
            if [ -n "$last" ] && [ -f "$state" ]; then
              find "$sv" -xdev -type f -newercm "$state" -print0 \
                | xargs -0 -r btrfs filesystem defragment -f -czstd -L "$level"
            else
              btrfs filesystem defragment -r -f -czstd -L "$level" "$sv"
            fi
            echo "storage-compress: after $sv"
            compsize -x "$sv" || echo "storage-compress: compsize failed on $sv"
            echo "$gen" > "$state"
          done
        '';
      };
    in
    {
      _class = "nixos";
      options.myModules.storage.compress = {
        enable = lib.mkEnableOption "periodic btrfs recompression of configured subvolumes";
        subvolumes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Absolute paths of btrfs subvolumes to recompress. Each must be a real subvolume: the O(1) generation skip and the incremental scan are per-subvolume, and defrag does not cross subvolume boundaries.";
        };
        level = lib.mkOption {
          type = lib.types.ints.between 1 15;
          default = 15;
          description = "zstd level. 15 is btrfs's transparent maximum; zstd decompression is level-independent, so it costs nothing on read -- only write-time CPU inside the idle-priority pass.";
        };
        schedule = lib.mkOption {
          type = lib.types.str;
          default = "daily";
          description = "systemd OnCalendar spec for the recompression timer.";
        };
        randomizedDelay = lib.mkOption {
          type = lib.types.str;
          default = "3h";
          description = "systemd RandomizedDelaySec: with Persistent=true, spreads the run (including a boot-time catch-up on a not-always-on machine) across a window so it never fires the instant the machine boots.";
        };
      };
      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.subvolumes != [ ];
            message = "myModules.storage.compress.subvolumes must list at least one subvolume";
          }
          {
            assertion = lib.all (d: lib.hasPrefix "/" d) cfg.subvolumes;
            message = "myModules.storage.compress.subvolumes entries must be absolute paths";
          }
        ];
        environment.systemPackages = [ pkgs.compsize ];
        systemd.services.storage-compress = {
          description = "Recompress btrfs subvolumes (defrag -czstd)";
          unitConfig.RequiresMountsFor = cfg.subvolumes;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe script;
            StateDirectory = "storage-compress";
            Nice = 19;
            IOSchedulingClass = "idle";
            CPUSchedulingPolicy = "batch";
            CPUWeight = 30;
            IOWeight = 30;
            OOMScoreAdjust = 1000;
            PrivateTmp = true;
            TimeoutStartSec = "24h";
          };
        };
        systemd.timers.storage-compress = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.schedule;
            Persistent = true;
            RandomizedDelaySec = cfg.randomizedDelay;
          };
        };
      };
    };
in
{
  flake.modules.nixos.storage-compress = mod;
}

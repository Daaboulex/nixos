# iodiag — one-shot I/O pressure diagnostic snapshot.
#
# Captures: /proc/pressure/{io,cpu,memory}, top I/O processes (D state),
# btrfs/nix-daemon activity, disk queue depth. Writes a dated report to
# ~/.cache/iodiag/ so cumulative evidence builds up. Run `iodiag` when
# you notice a hang; review with `iodiag --list` or `iodiag --latest`.
#
# Relies on sysstat + iotop-c (enable those modules). No root — reads
# /proc and runs iotop-c which needs CAP_NET_ADMIN via setcap; sysstat
# iostat is unprivileged.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.iodiag;

  iodiagScript = pkgs.writeShellScriptBin "iodiag" ''
    set -eu
    export PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gawk
        pkgs.gnugrep
      ]
    }''${PATH:+:$PATH}"
    DIR="$HOME/.cache/iodiag"
    mkdir -p "$DIR"
    STAMP=$(date +%Y-%m-%dT%H-%M-%S)
    OUT="$DIR/$STAMP.log"

    case "''${1:-}" in
      --list) ls -lht "$DIR" | head -20; exit 0 ;;
      --latest) f=$(ls -t "$DIR"/*.log 2>/dev/null | head -1); [ -n "$f" ] && ''${PAGER:-less} "$f"; exit 0 ;;
      --help) echo "iodiag [--list|--latest|--help]"; echo "  (no args) = capture snapshot"; exit 0 ;;
    esac

    {
      echo "=== iodiag snapshot $STAMP ==="
      echo
      echo "=== /proc/pressure ==="
      for f in cpu memory io; do echo "--- $f ---"; cat /proc/pressure/$f; done
      echo
      echo "=== top CPU (processes) ==="
      ${pkgs.procps}/bin/ps auxf --sort=-%cpu --no-headers | head -15
      echo
      echo "=== processes in D (uninterruptible) state ==="
      ${pkgs.procps}/bin/ps -eo pid,state,comm,wchan,cmd | awk '$2 ~ /D/' | head -15
      echo
      echo "=== iostat 1s x3 ==="
      ${pkgs.sysstat}/bin/iostat -xm 1 3 2>&1 | tail -25 || echo "sysstat not available"
      echo
      echo "=== zram ==="
      ${pkgs.util-linux}/bin/zramctl 2>/dev/null
      echo
      echo "=== swap ==="
      ${pkgs.util-linux}/bin/swapon --show 2>/dev/null
      echo
      echo "=== memory ==="
      ${pkgs.procps}/bin/free -h
      echo
      echo "=== recent btrfs/nix kernel log ==="
      ${pkgs.systemd}/bin/journalctl -k --since "2 minutes ago" --no-pager 2>&1 \
        | grep -iE "btrfs|nix-daemon|hung_task|blocked|ata" | tail -20
      echo
      echo "=== disk queue depth (sda) ==="
      for d in /sys/block/*/stat; do echo "$d:"; cat "$d"; done 2>/dev/null
      echo "=== /proc/diskstats ==="
      grep -E " sd[ab]\b| nvme" /proc/diskstats 2>/dev/null | head
    } | tee "$OUT"

    echo
    echo "Saved: $OUT"
    echo "Next: iodiag --list  or  iodiag --latest"
  '';
in
{
  options.myModules.home.iodiag.enable =
    lib.mkEnableOption "iodiag: one-shot I/O pressure diagnostic script";

  config = lib.mkIf cfg.enable {
    home.packages = [ iodiagScript ];
  };
}

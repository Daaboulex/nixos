# backup — Kingston A400 as this host's btrbk backup target.
#
# The storage-btrbk module owns the machinery (crypttab unlock, mounts,
# scrub, restore tool); this file only parameterizes it for this host.
# The swap partition on the same disk (cryptswap) is owned by the
# hibernate module: unlocked in initrd via the cached cryptroot
# passphrase, with resume= wired there.
{ lib, ... }:
{
  myModules.storage.btrbk = {
    enable = lib.mkForce true; # opt-in over the exhaustive-reference false in default.nix
    sourcePath = "/mnt/btrfs-root";
    sourceAnchorDevice = "/dev/mapper/cryptroot";
    targetPath = "/mnt/kingston-backup";
    # @nix excluded: reproducible from flake.lock -- snapshots waste 50+ GB.
    # @log excluded: ephemeral data, journald handles retention.
    subvolumes = [
      "@"
      "@home"
    ];
    # Minimal local retention -- deep history belongs on the Kingston target.
    # Must exceed the 6h send cadence or the incremental parent gets pruned
    # and every send degrades to a full transfer.
    snapshotPreserve = "12h";
    # 4 sends/day: hourly cadence produced 24 wakeups/day and long receive
    # windows that hibernate kept interrupting (partial subvols on target).
    timer = "*-*-* 00/6:00:00";
    # 208G target holding a 146G source: the default 12-month depth filled
    # it to 98% and stalled receives. ~47 snapshots/subvol keeps headroom.
    targetPreserve = "24h 14d 6w 3m";
  };

  # Kingston backup drive: LUKS unlock + mount owned by storage-crypt-drives
  # (the single crypttab writer); btrbk above replicates into targetPath.
  myModules.storage.cryptDrives.cryptbackup = {
    device = "UUID=745f4c07-14f5-4327-ac09-4de4e7192656";
    # On the encrypted root, never initrd: an initrd keyfile lands on
    # unencrypted /boot vfat, readable with physical access.
    keyFile = "/var/lib/secrets/kingston.key";
    mounts."/mnt/kingston-backup".fsOptions = [
      "compress=zstd:3"
      "noatime"
      "ssd"
      "discard=async"
      "commit=120"
      "nofail"
      "x-systemd.device-timeout=30s"
    ];
  };

  myModules.storage.displayNames."/mnt/kingston-backup" = "Kingston-Backup";

  # Root only; every cryptDrives mount adds itself to the same timer
  # (interval is one global setting).
  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
    fileSystems = [ "/" ];
  };

  # Keyfile migration at activation: runs before any service (or the next
  # boot's cryptsetup unit) can look for the new path. Copy-if-absent:
  # never overwrites. MINIMIZE-DEBT: drop this block once this host has
  # rebuilt past the relocation (check: ls /var/lib/secrets).
  system.activationScripts.kingston-key-relocation.text = ''
    if [ ! -e /var/lib/secrets/kingston.key ] && [ -e /etc/secrets/kingston.key ]; then
      mkdir -p /var/lib/secrets
      chmod 700 /var/lib/secrets
      cp -a /etc/secrets/kingston.key /var/lib/secrets/kingston.key
      chmod 400 /var/lib/secrets/kingston.key
    fi
    # Fail the activation loudly rather than boot into a system whose
    # crypttab points at a keyfile that never arrived.
    if [ ! -e /var/lib/secrets/kingston.key ] && [ -e /etc/secrets/kingston.key ]; then
      echo "kingston-key-relocation: FAILED to copy kingston.key to /var/lib/secrets; aborting activation. Original untouched at /etc/secrets." >&2
      exit 1
    fi
  '';
}

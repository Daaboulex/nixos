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
    targetDrive = {
      luksUuid = "745f4c07-14f5-4327-ac09-4de4e7192656";
      # Lives on the encrypted Samsung root -- an initrd keyfile would be
      # copied to UNENCRYPTED /boot vfat and readable with physical access.
      # Outside /etc: /etc carries no load-bearing runtime state (the etc
      # overlay hides anything not managed by environment.etc).
      keyFile = "/var/lib/secrets/kingston.key";
    };
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

  # Root-filesystem scrub; the btrbk module adds the backup target to the
  # same timer (interval is one global setting).
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

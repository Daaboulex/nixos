# kingston — Kingston A400 cryptbackup (btrbk target).
#
# The swap partition on this disk (cryptswap) is owned by the hibernate
# module: unlocked in initrd via the cached cryptroot passphrase (no
# keyfile), with resume= wired there. Only cryptbackup is unlocked here.
#
# cryptbackup is unlocked POST-ROOT from /etc/crypttab via keyfile (not
# initrd) so the keyfile stays on the encrypted Samsung root — an initrd
# keyfile would be copied to UNENCRYPTED /boot vfat and readable with
# physical access. 'nofail' lets the system boot if the Kingston is missing.
{
  config,
  lib,
  ...
}:
{
  # Enforce keyfile permissions declaratively — prevents drift if someone
  # later does `chmod 444` etc. tmpfiles 'z' verb fixes mode + ownership
  # on every boot without re-creating the file.
  systemd.tmpfiles.rules = [
    "d /etc/secrets 0700 root root -"
    "z /etc/secrets/kingston.key 0400 root root -"
  ];

  # Post-root LUKS unlock via systemd-cryptsetup generator.
  # 'nofail' = don't block boot if device missing. 'discard' = SSD TRIM.
  # cryptswap is NOT here — hibernate.nix opens it in initrd (resume=).
  environment.etc.crypttab.text = ''
    cryptbackup  UUID=745f4c07-14f5-4327-ac09-4de4e7192656  /etc/secrets/kingston.key  luks,discard,nofail
  '';

  fileSystems."/mnt/kingston-backup" = {
    device = "/dev/mapper/cryptbackup";
    fsType = "btrfs";
    options = [
      "compress=zstd:3"
      "noatime"
      "ssd"
      "discard=async"
      "nofail" # don't block boot if Kingston missing
      "x-systemd.device-timeout=30s" # A400 LUKS open takes ~12 s — needs headroom
    ];
  };

  # Top-level btrfs mount on the Samsung root filesystem.
  # Why: btrbk's `volume.<path>` directive expects <path> to be a location
  # where child subvolumes are directly reachable as <path>/@, <path>/@home,
  # etc. Our normal layout mounts @ AS /, @home AS /home, so the paths /@
  # and /@home do not exist — btrbk fails with "Failed to fetch subvolume
  # detail" every hour. Mounting subvolid=5 (the top-level fs root) at
  # /mnt/btrfs-root gives btrbk the anchor it needs without reshaping the
  # production mount tree. subvolid is stable — unlike subvol=/, which is
  # accepted but not documented to always map to subvolid=5.
  fileSystems."/mnt/btrfs-root" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [
      "subvolid=5" # top-level, stable identifier
      "compress=zstd:1" # match per-subvol zstd:1 so re-reads aren't recompressed
      "noatime"
      "ssd"
      "discard=async"
      "nosuid"
      "nodev"
      "noexec" # nothing ever needs to execute out of this admin-only view
    ];
  };

  myModules.storage.btrbk = {
    enable = lib.mkForce true;
    sourcePath = "/mnt/btrfs-root";
    targetPath = "/mnt/kingston-backup";
    # @nix excluded: reproducible from flake.lock — snapshots waste 50+ GB.
    # @log excluded: 17 MB ephemeral data, journald handles retention.
    subvolumes = [
      "@"
      "@home"
    ];
    # Minimal local retention — deep history belongs on Kingston target.
    # "2h" keeps enough for incremental sends; everything older is on target only.
    snapshotPreserve = "2h";
  };

  # Weekly btrfs scrub on the Kingston backup — detects silent bit-rot /
  # bad sectors on the A400 before they corrupt received snapshots. NixOS
  # wires this to a systemd timer. The backup filesystem is cold (only
  # written by hourly btrbk), so scrub is cheap + can run during idle.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
    fileSystems = [
      "/"
      "/mnt/kingston-backup"
    ];
  };
}

# kingston — Kingston A400 as LUKS swap + btrbk backup target.
#
# Design: Kingston is unlocked POST-ROOT by systemd-cryptsetup generator
# from /etc/crypttab (NOT initrd). Two benefits:
#
#   1. Keyfile stays inside encrypted Samsung root
#      (/etc/secrets/kingston.key). If the keyfile were used by initrd,
#      NixOS would copy it into the initrd image which sits on
#      UNENCRYPTED /boot vfat — anyone with physical access could read
#      it and defeat Kingston LUKS entirely.
#
#   2. If Kingston fails or is disconnected, Samsung still boots.
#      'nofail' in crypttab + filesystem options means systemd logs the
#      failure and continues. Without this, missing Kingston = initrd
#      hang = unbootable system.
#
# Trade-off: Kingston mounts ~2-3 s after root mount (post-systemd boot).
# Swap activation is therefore slightly delayed. Acceptable since zram
# is primary swap and handles the boot-time memory load alone.
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
  # 'nofail' = don't block boot if device missing.
  # 'discard' = SSD TRIM passthrough.
  environment.etc.crypttab.text = ''
    cryptswap    UUID=4728138f-08c2-4fa2-a77b-3e12e3c1347c  /etc/secrets/kingston.key  luks,discard,nofail
    cryptbackup  UUID=745f4c07-14f5-4327-ac09-4de4e7192656  /etc/secrets/kingston.key  luks,discard,nofail
  '';

  swapDevices = [
    {
      # By-label — NixOS derives /dev/disk/by-label/kingston-swap once
      # cryptswap mapper opens. Falls back silently if swap can't activate.
      label = "kingston-swap";
      priority = 10; # below zram (PRIO 100)
    }
  ];

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

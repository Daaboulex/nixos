{ config, pkgs, lib, ... }:

let
  cfg = config.myModules.system.filesystems;
in
{
  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.system.filesystems = {
    enable = lib.mkEnableOption "Universal filesystem support";

    enableAll = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable support for all common filesystems (recommended)";
    };

    enableLinux = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Linux filesystems (ext4, btrfs, xfs, f2fs)";
    };

    enableWindows = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Windows filesystems (NTFS, exFAT, FAT32)";
    };

    enableMac = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable macOS filesystems (HFS+)";
    };

    enableOptical = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable optical media filesystems (ISO9660, UDF)";
    };

    enableLegacy = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable legacy filesystems (ReiserFS) - not recommended";
    };
  };

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf cfg.enable {
    # ==========================================================================
    # Supported Filesystems for Boot
    # ==========================================================================
    boot.supportedFilesystems = lib.mkMerge [
      # Linux filesystems
      (lib.mkIf (cfg.enableAll || cfg.enableLinux) [
        "ext4"      # Fourth Extended Filesystem (most common Linux FS)
        "btrfs"     # B-tree Filesystem (copy-on-write, snapshots)
        "xfs"       # XFS (high-performance journaling FS)
        "f2fs"      # Flash-Friendly Filesystem (optimized for SSDs)
      ])

      # Windows filesystems
      (lib.mkIf (cfg.enableAll || cfg.enableWindows) [
        "ntfs"      # New Technology File System
        "exfat"     # Extended File Allocation Table
        "vfat"      # Virtual FAT (FAT32/FAT16)
      ])

      # macOS filesystems
      (lib.mkIf (cfg.enableAll || cfg.enableMac) [
        "hfsplus"   # Hierarchical File System Plus (macOS)
      ])

      # Optical media filesystems
      (lib.mkIf (cfg.enableAll || cfg.enableOptical) [
        "iso9660"   # ISO 9660 (CD-ROM)
        "udf"       # Universal Disk Format (DVD/Blu-ray)
      ])

      # Legacy filesystems
      (lib.mkIf cfg.enableLegacy [
        "reiserfs"  # ReiserFS (deprecated, use only if needed)
      ])
    ];

    # ==========================================================================
    # Kernel Modules for Filesystem Support
    # ==========================================================================
    boot.kernelModules = lib.mkMerge [
      # Linux filesystem modules
      (lib.mkIf (cfg.enableAll || cfg.enableLinux) [
        "ext4"
        "btrfs"
        "xfs"
        "f2fs"
      ])

      # Windows filesystem modules
      (lib.mkIf (cfg.enableAll || cfg.enableWindows) [
        "vfat"
        "exfat"
        "ntfs3"     # Native NTFS3 kernel driver (faster than FUSE)
      ])

      # macOS filesystem modules
      (lib.mkIf (cfg.enableAll || cfg.enableMac) [
        "hfsplus"
      ])

      # Optical media modules
      (lib.mkIf (cfg.enableAll || cfg.enableOptical) [
        "isofs"
        "udf"
      ])

      # Legacy filesystem modules
      (lib.mkIf cfg.enableLegacy [
        "reiserfs"
      ])
    ];

    # ==========================================================================
    # Filesystem Utilities
    # ==========================================================================
    environment.systemPackages = with pkgs; lib.mkMerge [
      # Linux filesystem tools
      (lib.mkIf (cfg.enableAll || cfg.enableLinux) [
        e2fsprogs      # ext2/ext3/ext4 utilities (mkfs.ext4, fsck.ext4, etc.)
        btrfs-progs    # Btrfs utilities (mkfs.btrfs, btrfs-check, etc.)
        xfsprogs       # XFS utilities (mkfs.xfs, xfs_repair, etc.)
        f2fs-tools     # F2FS utilities (mkfs.f2fs, fsck.f2fs, etc.)
      ])

      # Windows filesystem tools
      (lib.mkIf (cfg.enableAll || cfg.enableWindows) [
        dosfstools     # FAT/FAT32 utilities (mkfs.vfat, fsck.vfat, etc.)
        exfatprogs     # exFAT utilities (mkfs.exfat, fsck.exfat, etc.)
        ntfs3g         # NTFS utilities (mkfs.ntfs, ntfsfix, etc.)
      ])

      # Optical media tools
      (lib.mkIf (cfg.enableAll || cfg.enableOptical) [
        udftools       # UDF utilities (mkudffs, udffsck, etc.)
      ])

      # Common partitioning utilities (always included)
      [
        gptfdisk       # GPT partitioning (gdisk, sgdisk, cgdisk)
        parted         # Partition management (parted, partprobe)
      ]
    ];
  };
}

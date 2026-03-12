{ inputs, ... }:
{
  flake.nixosModules.system-filesystems =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.system.filesystems;
    in
    {
      _class = "nixos";
      options.myModules.system.filesystems = {
        enable = lib.mkEnableOption "Universal filesystem support";
        enableAll = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "All filesystem categories (overrides individual toggles)";
        };
        enableLinux = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Linux filesystems (ext4, btrfs, xfs, f2fs)";
        };
        enableWindows = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Windows filesystems (NTFS, exFAT, FAT32)";
        };
        enableMac = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "macOS filesystems (HFS+)";
        };
        enableOptical = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Optical disc filesystems (ISO 9660, UDF)";
        };
        enableLegacy = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Legacy filesystems (ReiserFS)";
        };
      };

      config = lib.mkIf cfg.enable {
        boot.supportedFilesystems = lib.mkMerge [
          (lib.mkIf (cfg.enableAll || cfg.enableLinux) [
            "ext4"
            "btrfs"
            "xfs"
            "f2fs"
          ])
          (lib.mkIf (cfg.enableAll || cfg.enableWindows) [
            "ntfs"
            "exfat"
            "vfat"
          ])
          (lib.mkIf (cfg.enableAll || cfg.enableMac) [ "hfsplus" ])
          (lib.mkIf (cfg.enableAll || cfg.enableOptical) [
            "iso9660"
            "udf"
          ])
          (lib.mkIf cfg.enableLegacy [ "reiserfs" ])
        ];

        boot.kernelModules = lib.mkMerge [
          (lib.mkIf (cfg.enableAll || cfg.enableLinux) [
            "ext4"
            "btrfs"
            "xfs"
            "f2fs"
          ])
          (lib.mkIf (cfg.enableAll || cfg.enableWindows) [
            "vfat"
            "exfat"
            "ntfs3"
          ])
          (lib.mkIf (cfg.enableAll || cfg.enableMac) [ "hfsplus" ])
          (lib.mkIf (cfg.enableAll || cfg.enableOptical) [
            "isofs"
            "udf"
          ])
          (lib.mkIf cfg.enableLegacy [ "reiserfs" ])
        ];

        environment.systemPackages =
          with pkgs;
          lib.mkMerge [
            (lib.mkIf (cfg.enableAll || cfg.enableLinux) [
              e2fsprogs
              btrfs-progs
              xfsprogs
              f2fs-tools
            ])
            (lib.mkIf (cfg.enableAll || cfg.enableWindows) [
              dosfstools
              exfatprogs
              ntfs3g
            ])
            (lib.mkIf (cfg.enableAll || cfg.enableOptical) [ udftools ])
            [
              gptfdisk
              parted
            ]
          ];
      };
    };
}

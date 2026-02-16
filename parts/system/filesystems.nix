{ inputs, ... }: {
  flake.nixosModules.system-filesystems = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.system.filesystems;
    in {
      options.myModules.system.filesystems = {
        enable = lib.mkEnableOption "Universal filesystem support";
        enableAll = lib.mkOption { type = lib.types.bool; default = true; };
        enableLinux = lib.mkOption { type = lib.types.bool; default = true; };
        enableWindows = lib.mkOption { type = lib.types.bool; default = true; };
        enableMac = lib.mkOption { type = lib.types.bool; default = true; };
        enableOptical = lib.mkOption { type = lib.types.bool; default = true; };
        enableLegacy = lib.mkOption { type = lib.types.bool; default = false; };
      };

      config = lib.mkIf cfg.enable {
        boot.supportedFilesystems = lib.mkMerge [
          (lib.mkIf (cfg.enableAll || cfg.enableLinux) [ "ext4" "btrfs" "xfs" "f2fs" ])
          (lib.mkIf (cfg.enableAll || cfg.enableWindows) [ "ntfs" "exfat" "vfat" ])
          (lib.mkIf (cfg.enableAll || cfg.enableMac) [ "hfsplus" ])
          (lib.mkIf (cfg.enableAll || cfg.enableOptical) [ "iso9660" "udf" ])
          (lib.mkIf cfg.enableLegacy [ "reiserfs" ])
        ];

        boot.kernelModules = lib.mkMerge [
          (lib.mkIf (cfg.enableAll || cfg.enableLinux) [ "ext4" "btrfs" "xfs" "f2fs" ])
          (lib.mkIf (cfg.enableAll || cfg.enableWindows) [ "vfat" "exfat" "ntfs3" ])
          (lib.mkIf (cfg.enableAll || cfg.enableMac) [ "hfsplus" ])
          (lib.mkIf (cfg.enableAll || cfg.enableOptical) [ "isofs" "udf" ])
          (lib.mkIf cfg.enableLegacy [ "reiserfs" ])
        ];

        environment.systemPackages = with pkgs; lib.mkMerge [
          (lib.mkIf (cfg.enableAll || cfg.enableLinux) [ e2fsprogs btrfs-progs xfsprogs f2fs-tools ])
          (lib.mkIf (cfg.enableAll || cfg.enableWindows) [ dosfstools exfatprogs ntfs3g ])
          (lib.mkIf (cfg.enableAll || cfg.enableOptical) [ udftools ])
          [ gptfdisk parted ]
        ];
      };
    };
}

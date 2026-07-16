# filesystems — universal filesystem support (ext4, btrfs, xfs, exfat, ntfs).
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
      cfg = config.myModules.storage.filesystems;
    in
    {
      _class = "nixos";
      options.myModules.storage.filesystems = {
        enable = lib.mkEnableOption "Universal filesystem support";
        enableLinux = lib.mkEnableOption "Linux filesystems (ext4, btrfs, xfs, f2fs)";
        enableWindows = lib.mkEnableOption "Windows filesystems (NTFS, exFAT, FAT32)";
        enableMac = lib.mkEnableOption "macOS filesystems (HFS+)";
        enableOptical = lib.mkEnableOption "Optical disc filesystems (ISO 9660, UDF)";
        enableLegacy = lib.mkEnableOption "Legacy filesystems (ReiserFS)";
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            # reiserfs was removed from Linux 6.13; enabling it on a newer
            # kernel would silently ship a filesystem the kernel cannot mount.
            assertion = cfg.enableLegacy -> lib.versionOlder config.boot.kernelPackages.kernel.version "6.13";
            message = "myModules.storage.filesystems.enableLegacy: reiserfs was removed from Linux 6.13; kernel ${config.boot.kernelPackages.kernel.version} cannot mount it.";
          }
        ];

        # The declared NTFS data disks are system-internal (removable=0), so
        # udisks2 demands the filesystem-mount-system polkit auth (a password)
        # when the file manager mounts them -- even though systemd's automount
        # already mounts them password-free on terminal access. Let the primary
        # user, at a LOCAL ACTIVE seat only, mount/unmount them from the desktop
        # without a prompt. Scoped to the enableWindows hosts (the only ones with
        # user-mounted internal disks); root auth is still required remotely or
        # for any other subject.
        security.polkit.extraConfig = lib.mkIf cfg.enableWindows ''
          polkit.addRule(function(action, subject) {
            if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
                 action.id == "org.freedesktop.udisks2.filesystem-unmount-others") &&
                subject.user == "${config.myModules.primaryUser}" &&
                subject.local && subject.active) {
              return polkit.Result.YES;
            }
          });
        '';
        boot.supportedFilesystems = lib.mkMerge [
          (lib.mkIf cfg.enableLinux [
            "ext4"
            "btrfs"
            "xfs"
            "f2fs"
          ])
          (lib.mkIf cfg.enableWindows [
            "ntfs"
            "exfat"
            "vfat"
          ])
          (lib.mkIf cfg.enableMac [ "hfsplus" ])
          (lib.mkIf cfg.enableOptical [
            "iso9660"
            "udf"
          ])
          (lib.mkIf cfg.enableLegacy [ "reiserfs" ])
        ];

        # No boot.kernelModules for these: supportedFilesystems above already makes
        # each driver available (and puts the root FS in the initrd), and the kernel
        # autoloads the right module on `mount -t <fs>` via its fs-<name> modalias.
        # Eager-loading all of them at every boot is redundant and slows systemd-
        # modules-load for filesystems most boots never touch (exfat/udf/iso/f2fs/xfs).

        environment.systemPackages =
          with pkgs;
          lib.mkMerge [
            (lib.mkIf cfg.enableLinux [
              e2fsprogs
              btrfs-progs
              xfsprogs
              f2fs-tools
            ])
            (lib.mkIf cfg.enableWindows [
              dosfstools
              exfatprogs
              ntfs3g
            ])
            (lib.mkIf cfg.enableOptical [ udftools ])
            [
              gptfdisk
              parted
              # testdisk is the HM module home/modules/testdisk/
              # gparted GUI is the HM module home/modules/gparted/
              libblockdev
            ]
          ];
      };
    };
in
{
  flake.modules.nixos.storage-filesystems = mod;

}

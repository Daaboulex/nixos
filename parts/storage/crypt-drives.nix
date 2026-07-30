# crypt-drives — LUKS2 keyfile-unlocked btrfs data drives; the single writer of /etc/crypttab
# and the sole mount owner. udisks is told to ignore the LUKS container, so a file manager
# cannot unlock the disk itself and mount it at a second path; the unlocked volume stays
# visible under its declared mount point. Owning the mount includes scrubbing it, so a host
# declares a drive once and never restates its path.
_:
let
  mod =
    {
      config,
      lib,
      myLib,
      ...
    }:
    let
      cfg = config.myModules.storage.cryptDrives;
      allMounts = lib.concatLists (
        lib.mapAttrsToList (
          name: d:
          lib.mapAttrsToList (mountPoint: m: {
            inherit name mountPoint;
            inherit (m) subvol fsOptions owner;
          }) d.mounts
        ) cfg
      );
      containerMatch = d: myLib.blockDevice.udevMatch d.device;
    in
    {
      _class = "nixos";
      options.myModules.storage.cryptDrives = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (
            { name, config, ... }:
            {
              options = {
                label = lib.mkOption {
                  type = lib.types.str;
                  default = "${name}-luks";
                  description = "LUKS2 header label the container is opened by.";
                };
                device = lib.mkOption {
                  type = lib.types.str;
                  default = "/dev/disk/by-label/${config.label}";
                  description = "crypttab device spec (default: by the LUKS label; override with UUID=... for a UUID-identified container).";
                };
                keyFile = lib.mkOption {
                  type = lib.types.str;
                  default = "/etc/cryptkeys/${name}.key";
                  description = "Keyfile on the encrypted root that unlocks the container at boot.";
                };
                luksOptions = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [
                    "luks"
                    "discard"
                    "no-read-workqueue"
                    "no-write-workqueue"
                    "nofail"
                  ];
                  description = "crypttab options for the container.";
                };
                mounts = lib.mkOption {
                  type = lib.types.attrsOf (
                    lib.types.submodule {
                      options = {
                        subvol = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "Btrfs subvolume mounted at this mount point (null = the drive's default subvolume, no subvol= option).";
                        };
                        fsOptions = lib.mkOption {
                          type = lib.types.listOf lib.types.str;
                          default = [
                            "compress=zstd"
                            "noatime"
                            "nofail"
                          ];
                          description = "Mount options for this mount.";
                        };
                        owner = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "User owning the mount root, so the drive is writable without root. Applied with a tmpfiles 'z' rule: adjust if present, never create, so a nofail drive that failed to unlock cannot fabricate an owned directory on the root filesystem. null leaves the on-disk ownership alone -- correct for a drive holding root-owned data such as a backup target.";
                        };
                      };
                    }
                  );
                  default = { };
                  description = "Mount points served from this drive, each from its own subvolume.";
                };
              };
            }
          )
        );
        default = { };
        description = "LUKS2 keyfile-unlocked btrfs data drives, keyed by mapper name.";
      };
      config = lib.mkIf (cfg != { }) {
        assertions =
          lib.concatLists (
            lib.mapAttrsToList (name: d: [
              {
                assertion = builtins.match "[a-z0-9-]+" name != null;
                message = "myModules.storage.cryptDrives: name '${name}' must match [a-z0-9-]+";
              }
              {
                assertion = lib.hasPrefix "/" d.keyFile;
                message = "myModules.storage.cryptDrives.${name}: keyFile must be absolute";
              }
              {
                assertion = d.mounts != { };
                message = "myModules.storage.cryptDrives.${name}: declares no mounts";
              }
            ]) cfg
          )
          ++ map (m: {
            assertion = lib.hasPrefix "/" m.mountPoint;
            message = "myModules.storage.cryptDrives.${m.name}: mount point '${m.mountPoint}' must be absolute";
          }) allMounts
          ++ lib.mapAttrsToList (name: d: {
            assertion = containerMatch d != null;
            message = "myModules.storage.cryptDrives.${name}: device '${d.device}' cannot be matched by a udev rule, so udisks could not be locked out of it — use UUID=, LABEL=, /dev/disk/by-uuid/ or /dev/disk/by-label/";
          }) cfg
          ++ [
            {
              assertion =
                lib.allUnique (lib.mapAttrsToList (_: d: d.device) cfg)
                && lib.allUnique (map (m: m.mountPoint) allMounts);
              message = "myModules.storage.cryptDrives: devices and mount points must be unique";
            }
          ];
        environment.etc.crypttab.text =
          lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              name: d: "${name} ${d.device} ${d.keyFile} ${lib.concatStringsSep "," d.luksOptions}"
            ) cfg
          )
          + "\n";
        fileSystems = lib.listToAttrs (
          map (
            m:
            lib.nameValuePair m.mountPoint {
              device = "/dev/mapper/${m.name}";
              fsType = "btrfs";
              options = lib.optional (m.subvol != null) "subvol=${m.subvol}" ++ m.fsOptions;
            }
          ) allMounts
        );
        systemd.tmpfiles.rules =
          lib.concatLists (
            lib.mapAttrsToList (_: d: [
              "d ${dirOf d.keyFile} 0700 root root -"
              "z ${d.keyFile} 0400 root root -"
            ]) cfg
          )
          ++ map (m: "z ${m.mountPoint} - ${m.owner} ${config.users.users.${m.owner}.group} -") (
            lib.filter (m: m.owner != null) allMounts
          );
        services.btrfs.autoScrub = {
          enable = true;
          fileSystems = map (m: m.mountPoint) allMounts;
        };
        services.udev.extraRules =
          lib.concatStringsSep "\n" (
            lib.concatLists (
              lib.mapAttrsToList (
                _: d:
                lib.optional (containerMatch d != null)
                  ''SUBSYSTEM=="block", ENV{ID_FS_TYPE}=="crypto_LUKS", ${containerMatch d}, ENV{UDISKS_IGNORE}="1"''
              ) cfg
            )
          )
          + "\n";
      };
    };
in
{
  flake.modules.nixos.storage-crypt-drives = mod;
}

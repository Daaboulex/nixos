# disko — declarative disk layout for macbook-pro-9-2 (Samsung root + Kingston swap/backup).
# Mirrors BTRFS + LUKS setup on the Samsung PM841 (main SATA bay) AND
# the Kingston A400 (optical-bay caddy) repurposed as encrypted swap
# + btrbk snapshot archive.
#
# For new installations (disaster recovery):
#   disko --mode disko ./disko.nix
#   nixos-install --flake .#macbook-pro-9-2
#
# For runtime, hardware-configuration.nix + kingston.nix are the
# active truth. This file stays in sync for DR rebuilds.
_: {
  disko.devices = {
    # Samsung PM841 — primary root (btrfs + LUKS)
    disk.main = {
      type = "disk";
      device = "/dev/disk/by-uuid/0d4eafad-07a3-4404-ad90-301b416bbb53";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [
                "fmask=0077"
                "dmask=0077"
              ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  "-L"
                  "nixos"
                ];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "@cache" = {
                    mountpoint = "/var/cache";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "@tmp" = {
                    mountpoint = "/tmp";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "@snapshots" = {
                    mountpoint = "/.snapshots";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "@persist" = {
                    mountpoint = "/persist";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };

    # Kingston A400 — repurposed: 16 GB LUKS swap + rest LUKS btrfs
    # btrbk snapshot archive. Keyfile auto-unlocks both at boot.
    disk.kingston = {
      type = "disk";
      device = "/dev/disk/by-id/${(import ../../../secrets/host-identifiers.nix).hardware.macbook-pro-9-2.kingstonDiskId}";
      content = {
        type = "gpt";
        partitions = {
          swap = {
            size = "16G";
            content = {
              type = "luks";
              name = "cryptswap";
              settings = {
                keyFile = "/etc/secrets/kingston.key";
                allowDiscards = true;
              };
              content = {
                type = "swap";
                resumeDevice = false;
              };
            };
          };
          backup = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptbackup";
              settings = {
                keyFile = "/etc/secrets/kingston.key";
                allowDiscards = true;
              };
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  "-L"
                  "kingston-backup"
                ];
                mountpoint = "/mnt/kingston-backup";
                mountOptions = [
                  "compress=zstd:3"
                  "noatime"
                  "ssd"
                  "discard=async"
                ];
              };
            };
          };
        };
      };
    };
  };
}

# disko — declarative disk layout for macbook-pro-9-2 (Samsung system disk only).
#
# Install-time ground truth, consumed by nixos-anywhere (the disko
# nixosModule is imported in flake-module.nix; enableConfig=false below
# keeps it inert at runtime) or standalone from an installer:
#   disko --mode disko ./disko.nix && nixos-install --flake .#macbook-pro-9-2
#
# The Kingston A400 (swap + btrbk backup archive) is deliberately NOT
# managed here: an install must never format the drive holding the
# backups being recovered. Runtime unlock/mount of the Kingston is owned
# by the hibernate module (cryptswap) and storage-btrbk (cryptbackup);
# its keyfile arrives via nrb --install's secrets seed. One-off format
# of a NEW Kingston (both partitions keyed by kingston.key):
#   sgdisk -n1:0:+16G -n2:0:0 <disk>
#   cryptsetup luksFormat --key-file /var/lib/secrets/kingston.key <disk>-part1
#   cryptsetup luksFormat --key-file /var/lib/secrets/kingston.key <disk>-part2
#   cryptsetup open --key-file /var/lib/secrets/kingston.key <disk>-part1 cryptswap && mkswap /dev/mapper/cryptswap
#   cryptsetup open --key-file /var/lib/secrets/kingston.key <disk>-part2 cryptbackup && mkfs.btrfs -L kingston-backup /dev/mapper/cryptbackup
_: {
  # Runtime fileSystems/crypttab are owned by hardware-configuration.nix
  # and the storage modules; disko contributes install-time layout only.
  disko.enableConfig = false;

  disko.devices = {
    # Samsung PM841 — primary root (btrfs + LUKS). by-path = the main SATA
    # bay, stable across disk replacement; a by-uuid/by-id device would be
    # unresolvable on the NEW disk a disaster recovery installs onto.
    disk.main = {
      type = "disk";
      device = "/dev/disk/by-path/pci-0000:00:1f.2-ata-1";
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
              settings = {
                # Install-time key: nrb --install pipes the typed passphrase
                # here (newline-free) via --disk-encryption-keys, so keyslot 0
                # holds exactly the bytes typed at the boot prompt.
                keyFile = "/tmp/cryptroot.key";
              };
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
                      "compress=zstd:1"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd:1"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd:1"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [
                      "compress=zstd:1"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "@cache" = {
                    mountpoint = "/var/cache";
                    mountOptions = [
                      "compress=zstd:1"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "@tmp" = {
                    mountpoint = "/tmp";
                    mountOptions = [
                      "compress=zstd:1"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "@snapshots" = {
                    mountpoint = "/.snapshots";
                    mountOptions = [
                      "compress=zstd:1"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "@persist" = {
                    mountpoint = "/persist";
                    mountOptions = [
                      "compress=zstd:1"
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
  };
}

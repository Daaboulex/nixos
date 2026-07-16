# disko — declarative disk layout for ryzen-9950x3d (system NVMe only).
#
# Install-time ground truth, consumed by nixos-anywhere (the disko
# nixosModule is imported in flake-module.nix; enableConfig=false below
# keeps it inert at runtime) or standalone from an installer:
#   disko --mode disko ./disko.nix && nixos-install --flake .#ryzen-9950x3d
#
# ONLY the system NVMe lives here. The NTFS data drives (Windows SSD,
# HDD) and the two VFIO VM NVMe disks (pci 0b:00.0 / 0f:00.0) must NEVER
# be managed by disko — an install would destroy them.
_: {
  # Runtime fileSystems/crypttab are owned by hardware-configuration.nix;
  # disko contributes install-time layout only.
  disko.enableConfig = false;

  disko.devices = {
    disk.main = {
      type = "disk";
      # by-path = the PCIe slot of the system NVMe, stable across disk
      # replacement; a by-uuid/by-id device would be unresolvable on the
      # NEW disk a disaster recovery installs onto.
      device = "/dev/disk/by-path/pci-0000:04:00.0-nvme-1";
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
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@cache" = {
                    mountpoint = "/var/cache";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@tmp" = {
                    mountpoint = "/var/tmp";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@snapshots" = {
                    mountpoint = "/.snapshots";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@persist" = {
                    mountpoint = "/persist";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
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

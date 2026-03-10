# Declarative disk layout for macbook-pro-9-2
# Mirrors the existing BTRFS + LUKS setup from hardware-configuration.nix
# SSD-optimized mount options: ssd, discard=async
#
# For new installations: disko --mode disko ./disko.nix
# Then: nixos-install --flake .#macbook-pro-9-2
{ ... }: {
  disko.devices = {
    disk.main = {
      type = "disk";
      # Set to actual disk path at install time (e.g. /dev/sda)
      device = "/dev/disk/by-uuid/afed0ac1-2abb-4074-a3ff-6971a352b7e8";
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
              mountOptions = [ "fmask=0077" "dmask=0077" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" "-L" "nixos" ];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" "ssd" "discard=async" ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [ "compress=zstd" "noatime" "ssd" "discard=async" ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd" "noatime" "ssd" "discard=async" ];
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [ "compress=zstd" "noatime" "ssd" "discard=async" ];
                  };
                  "@cache" = {
                    mountpoint = "/var/cache";
                    mountOptions = [ "compress=zstd" "noatime" "ssd" "discard=async" ];
                  };
                  "@tmp" = {
                    mountpoint = "/tmp";
                    mountOptions = [ "compress=zstd" "noatime" "ssd" "discard=async" ];
                  };
                  "@snapshots" = {
                    mountpoint = "/.snapshots";
                    mountOptions = [ "compress=zstd" "noatime" "ssd" "discard=async" ];
                  };
                  "@persist" = {
                    mountpoint = "/persist";
                    mountOptions = [ "compress=zstd" "noatime" "ssd" "discard=async" ];
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

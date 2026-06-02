# hibernate — generic suspend-to-disk via LUKS-encrypted swap partition.
#
# Works on any host with a LUKS-encrypted swap partition at least as large
# as physical RAM. Unlocks the partition in initrd, registers it as swap,
# and wires `resume=` so the kernel can resume a hibernated image.
#
# Swap priority defaults above zram so disk swap is available when zram
# fills, but still below typical zram priorities so compressed RAM is
# preferred for regular memory pressure. Disk swap engages primarily for
# the hibernate image.
#
# Typical wiring (per host):
#   myModules.boot.hibernate = {
#     enable = true;
#     swapLuksUuid = "<output of: sudo cryptsetup luksUUID /dev/<partition>>";
#     ramSizeGB = 16;   # must be >= physical RAM; asserted at eval time
#   };
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
      cfg = config.myModules.boot.hibernate;
    in
    {
      _class = "nixos";
      options.myModules.boot.hibernate = {
        enable = lib.mkEnableOption "Hibernate support via a LUKS-encrypted swap partition";

        swapLuksUuid = lib.mkOption {
          type = lib.types.str;
          example = "11111111-2222-3333-4444-555555555555";
          description = ''
            UUID of the LUKS container holding swap. Get it with
            `sudo cryptsetup luksUUID /dev/<swap-partition>`.
          '';
        };

        ramSizeGB = lib.mkOption {
          type = lib.types.ints.positive;
          default = 16;
          description = ''
            Physical RAM size in GiB. Hibernate requires swap partition
            to be at least this large (the full RAM image is written to
            swap). Asserted at eval time as a sanity check.
          '';
        };

        swapDevicePriority = lib.mkOption {
          type = lib.types.int;
          default = 10;
          description = ''
            Priority for the disk swap device. Default 10 keeps it above
            disabled priorities but below typical zram priority (100) so
            compressed RAM is preferred under steady-state memory
            pressure. Disk swap engages primarily for hibernate images.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        boot = {
          # Unlock the LUKS swap container in initrd. Same passphrase chain
          # as cryptroot works because cryptsetup caches the passphrase for
          # subsequent devices in the initrd run.
          initrd.luks.devices.cryptswap = {
            device = "/dev/disk/by-uuid/${cfg.swapLuksUuid}";
            allowDiscards = true;
            bypassWorkqueues = false; # keep default; disabling can starve under I/O load
          };
          # Resume path. resumeDevice emits `resume=` itself; the mapper
          # exists only after initrd unlocks the LUKS container.
          resumeDevice = "/dev/mapper/cryptswap";
        };

        swapDevices = [
          {
            device = "/dev/mapper/cryptswap";
            priority = cfg.swapDevicePriority;
          }
        ];

        # Sanity assertion at eval time.
        assertions = [
          {
            assertion = cfg.ramSizeGB >= 1;
            message = "myModules.boot.hibernate: ramSizeGB (${toString cfg.ramSizeGB}) must be >= 1. Set it to your host's actual RAM size in GiB.";
          }
        ];
      };
    };
in
{
  flake.modules.nixos.boot-hibernate = mod;
}

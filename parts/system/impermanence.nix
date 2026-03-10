# Impermanence — erase root subvolume on every boot, persist only declared state.
#
# Phase 1: system-only impermanence. /home remains on its own persistent subvolume.
#
# ── Prerequisites (run once on a live system before enabling) ─────────────────
#
#   # 1. Create the @persist subvolume
#   sudo mount -t btrfs -o subvol=/ /dev/mapper/cryptroot /mnt
#   sudo btrfs subvolume create /mnt/@persist
#
#   # 2. Create the blank root snapshot (used for rollback)
#   sudo btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank
#
#   # 3. Copy current system state that must survive into @persist
#   sudo mkdir -p /mnt/@persist
#   for d in /var/lib/nixos /var/lib/systemd /var/lib/bluetooth /var/lib/flatpak \
#            /var/lib/colord /var/lib/NetworkManager /var/lib/portmaster \
#            /var/lib/upower /var/lib/sops-nix /var/lib/sbctl \
#            /etc/NetworkManager/system-connections /etc/ssh; do
#     [ -d "$d" ] && sudo mkdir -p "/mnt/@persist$d" && sudo cp -a "$d/." "/mnt/@persist$d/"
#   done
#   [ -f /etc/machine-id ] && sudo cp /etc/machine-id /mnt/@persist/etc/machine-id
#
#   sudo umount /mnt
#
#   # 4. Enable in host config:
#   #   myModules.system.impermanence.enable = true;
#
# ─────────────────────────────────────────────────────────────────────────────
{ inputs, ... }: {
  flake.nixosModules.system-impermanence = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.system.impermanence;
    in {
      _class = "nixos";
      options.myModules.system.impermanence = {
        enable = lib.mkEnableOption "Impermanence (erase root on every boot)";

        persistPath = lib.mkOption {
          type = lib.types.path;
          default = "/persist";
          description = "Mountpoint for the persistent BTRFS subvolume";
        };

        luksDevice = lib.mkOption {
          type = lib.types.str;
          default = "cryptroot";
          description = "LUKS device mapper name (e.g. cryptroot)";
        };

        rollback = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable initrd rollback service that erases root on every boot";
          };

          blankSnapshot = lib.mkOption {
            type = lib.types.str;
            default = "@root-blank";
            description = "Name of the read-only blank root snapshot";
          };

          rootSubvolume = lib.mkOption {
            type = lib.types.str;
            default = "@";
            description = "Name of the root BTRFS subvolume";
          };
        };

        extraDirectories = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.str lib.types.attrs);
          default = [ ];
          description = "Extra system directories to persist";
        };

        extraFiles = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra system files to persist";
        };
      };

      config = lib.mkIf cfg.enable {
        # ── Initrd rollback service ───────────────────────────────────────
        # Deletes the root subvolume and restores it from the blank snapshot.
        # Runs in initrd after LUKS is unlocked but before sysroot is mounted.
        boot.initrd.systemd.services.rollback = lib.mkIf cfg.rollback.enable {
          description = "Rollback BTRFS root to blank snapshot";
          wantedBy = [ "initrd.target" ];
          after = [ "systemd-cryptsetup@${cfg.luksDevice}.service" ];
          before = [ "sysroot.mount" ];
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          script = ''
            mkdir -p /mnt
            mount -t btrfs -o subvol=/ /dev/mapper/${cfg.luksDevice} /mnt

            # Delete nested subvolumes that systemd creates under root
            btrfs subvolume list -o /mnt/${cfg.rollback.rootSubvolume} |
              cut -d' ' -f9 | while read subvol; do
                btrfs subvolume delete "/mnt/$subvol" 2>/dev/null || true
              done

            btrfs subvolume delete /mnt/${cfg.rollback.rootSubvolume}
            btrfs subvolume snapshot /mnt/${cfg.rollback.blankSnapshot} /mnt/${cfg.rollback.rootSubvolume}
            umount /mnt
          '';
        };

        # ── Persistent subvolume mount ────────────────────────────────────
        fileSystems.${cfg.persistPath} = {
          device = "/dev/mapper/${cfg.luksDevice}";
          fsType = "btrfs";
          options = [ "subvol=@persist" "compress=zstd" "noatime" ];
          neededForBoot = true;
        };

        # /var/log is a separate subvolume but impermanence bind mounts
        # need it available early during boot
        fileSystems."/var/log".neededForBoot = true;

        # ── Persistent state declarations ─────────────────────────────────
        environment.persistence.${cfg.persistPath} = {
          hideMounts = true;
          directories = [
            "/var/lib/nixos"
            "/var/lib/systemd/coredump"
            "/var/lib/systemd/timers"
            "/var/lib/bluetooth"
            "/var/lib/flatpak"
            "/var/lib/colord"
            "/var/lib/NetworkManager"
            "/var/lib/portmaster"
            "/var/lib/upower"
            { directory = "/var/lib/sops-nix"; mode = "0700"; }
            { directory = "/var/lib/sbctl"; mode = "0700"; }
            { directory = "/etc/NetworkManager/system-connections"; mode = "0700"; }
            "/etc/ssh"
          ] ++ cfg.extraDirectories;
          files = [
            "/etc/machine-id"
          ] ++ cfg.extraFiles;
        };
      };
    };
}

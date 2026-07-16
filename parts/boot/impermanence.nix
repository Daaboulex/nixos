# impermanence — erase root filesystem on every boot, preserve only declared state.
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
      cfg = config.myModules.boot.impermanence;
    in
    {
      _class = "nixos";
      options.myModules.boot.impermanence = {
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
          type = lib.types.listOf (lib.types.either lib.types.str (lib.types.attrsOf lib.types.anything));
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
              sed -n 's/.* path //p' | while read -r subvol; do
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
          options = [
            "subvol=@persist"
            "compress=zstd"
            "noatime"
          ];
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
            {
              directory = "/var/lib/sbctl";
              mode = "0700";
            }
            {
              directory = "/etc/NetworkManager/system-connections";
              mode = "0700";
            }
            # Host-local secret files (LUKS keyfiles etc. -- see the btrbk
            # targetDrive.keyFile convention); outside /etc by design.
            {
              directory = "/var/lib/secrets";
              mode = "0700";
            }
          ]
          # sshd's host-key directories, DERIVED from the ssh config so a
          # future relocation can never leave this list stale (a stale
          # entry here means the real keys get wiped every boot and sshd
          # regenerates a new identity).
          ++ lib.unique (map (k: dirOf k.path) config.services.openssh.hostKeys)
          ++ cfg.extraDirectories;
          # /etc/machine-id is deliberately NOT here: it is declarative
          # (environment.etc from the site registry pin), and a persistence
          # bind mount would fight the managed file.
          files = cfg.extraFiles;
        };
      };
    };
in
{
  flake.modules.nixos.boot-impermanence = mod;

}

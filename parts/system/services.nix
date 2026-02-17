{ inputs, ... }: {
  flake.nixosModules.system-services = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.system.services;
    in {
      options.myModules.system.services = {
        enable = lib.mkEnableOption "Common system services";

        printing = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable printing support (CUPS)";
        };

        fstrim = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable periodic SSD TRIM";
          };
          interval = lib.mkOption {
            type = lib.types.str;
            default = "weekly";
            description = "How often to run fstrim";
          };
        };

        earlyoom = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable early OOM killer (prevents system freezes)";
          };
          freeMemThreshold = lib.mkOption {
            type = lib.types.int;
            default = 5;
            description = "Minimum free memory percentage before killing";
          };
          freeSwapThreshold = lib.mkOption {
            type = lib.types.int;
            default = 10;
            description = "Minimum free swap percentage before killing";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        services = {
          printing = lib.mkIf cfg.printing {
            enable = true;
            browsing = true;
            defaultShared = false;
            drivers = [ pkgs.gutenprint pkgs.gutenprintBin ];
          };

          libinput.enable = true;

          fstrim = lib.mkIf cfg.fstrim.enable {
            enable = true;
            interval = cfg.fstrim.interval;
          };

          earlyoom = lib.mkIf cfg.earlyoom.enable {
            enable = true;
            freeMemThreshold = cfg.earlyoom.freeMemThreshold;
            freeSwapThreshold = cfg.earlyoom.freeSwapThreshold;
            enableNotifications = true;
            extraArgs = [
              "--prefer" "^(Web Content|Isolated Web|firefox|chromium|steam|gamescope)$"
              "--avoid" "^(sshd|systemd|Xorg|Xwayland|kwin|plasmashell|pipewire|wireplumber)$"
            ];
          };

          acpid.enable = true;
          upower.enable = true;
          geoclue2.enable = true;
          usbmuxd.enable = true;
        };
      };
    };
}

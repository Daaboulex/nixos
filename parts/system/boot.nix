{ inputs, ... }: {
  flake.nixosModules.system-boot = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.system.boot;
      hostName = config.networking.hostName;
    in {
      options.myModules.system.boot = {
        enable = lib.mkEnableOption "Boot configuration";

        loader = lib.mkOption {
          type = lib.types.enum [ "systemd-boot" "grub" "none" ];
          default = "systemd-boot";
          description = "Bootloader to use";
        };

        secureBoot = {
          enable = lib.mkEnableOption "Lanzaboote secure boot";
          pkiBundle = lib.mkOption {
            type = lib.types.path;
            default = "/var/lib/sbctl";
            description = "Path to PKI bundle";
          };
        };

        plymouth = {
          enable = lib.mkEnableOption "Plymouth boot splash";
          theme = lib.mkOption {
            type = lib.types.str;
            default = "bgrt";
            description = "Plymouth theme to use";
          };
        };

        consoleMode = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "max";
          description = "Console resolution mode (max, keep, or specific like 1920x1080)";
        };
        
        initrd = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable systemd initrd and early KMS for Plymouth";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        # Initrd Configuration
        boot.initrd.systemd.enable = cfg.initrd.enable;
        
        # Early KMS: Force load graphics drivers in initrd for Plymouth
        # Handled by hardware.graphics.<vendor>.initrd.enable now
        boot.initrd.kernelModules = lib.optionals cfg.initrd.enable [ ];

        # Systemd-boot
        boot.loader.systemd-boot.enable = lib.mkIf (cfg.loader == "systemd-boot" && !cfg.secureBoot.enable) true;
        boot.loader.systemd-boot.configurationLimit = 10;
        boot.loader.efi.canTouchEfiVariables = true;
        boot.loader.timeout = 5;

        # GRUB
        boot.loader.grub.enable = lib.mkIf (cfg.loader == "grub") true;

        # Secure Boot (Lanzaboote)
        boot.lanzaboote.enable = lib.mkIf cfg.secureBoot.enable true;
        boot.lanzaboote.pkiBundle = lib.mkIf cfg.secureBoot.enable cfg.secureBoot.pkiBundle;
        
        # Plymouth
        boot.plymouth.enable = lib.mkIf cfg.plymouth.enable true;
        boot.plymouth.theme = lib.mkIf cfg.plymouth.enable cfg.plymouth.theme;

        # Console resolution
        boot.loader.systemd-boot.consoleMode = lib.mkIf (cfg.consoleMode != null) cfg.consoleMode;

        # Kernel parameters for clean boot
        boot.kernelParams = lib.optionals cfg.plymouth.enable [
          "quiet"
          "splash"
          "rd.systemd.show_status=false"
          "rd.udev.log_level=3"
          "udev.log_priority=3"
        ];

        environment.systemPackages = lib.optionals cfg.secureBoot.enable [ pkgs.sbctl ];
      };
    };
}

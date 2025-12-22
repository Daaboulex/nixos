{ config, pkgs, lib, ... }:
let
  cfg = config.myModules.boot;
  hostName = config.networking.hostName;
  isMacBook = lib.hasPrefix "macbook-pro" hostName;
in {
  options.myModules.boot = {
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
    boot.initrd.kernelModules = lib.optionals cfg.initrd.enable ([ "i915" ] ++ lib.optionals (!isMacBook) [ "amdgpu" ]);

    # Systemd-boot
    boot.loader.systemd-boot.enable = lib.mkIf (cfg.loader == "systemd-boot" && !cfg.secureBoot.enable) true;
    boot.loader.systemd-boot.configurationLimit = 10;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.timeout = 5;

    # GRUB (disabled by default here to enforce valid config, enabled if selected)
    boot.loader.grub.enable = lib.mkIf (cfg.loader == "grub") true;
    # Ensure mutually exclusive defaults don't conflict if user manually sets things, 
    # generally systemd-boot enable logic above handles the default case.

    # Secure Boot (Lanzaboote)
    boot.lanzaboote.enable = lib.mkIf cfg.secureBoot.enable true;
    boot.lanzaboote.pkiBundle = lib.mkIf cfg.secureBoot.enable cfg.secureBoot.pkiBundle;
    
    # If Lanzaboote is enabled, it handles systemd-boot installation, so we need to ensure standard systemd-boot is disabled?
    # Actually Lanzaboote replaces the loader logic. The condition `!cfg.secureBoot.enable` above handles this.

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
}
# loader — boot manager (systemd-boot, rEFInd, GRUB), Plymouth splash, and initrd.
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
      cfg = config.myModules.boot.loader;
    in
    {
      _class = "nixos";
      options.myModules.boot.loader = {
        enable = lib.mkEnableOption "Boot configuration";

        loader = lib.mkOption {
          type = lib.types.enum [
            "systemd-boot"
            "refind"
            "grub"
            "none"
          ];
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

        refind = {
          timeout = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 5;
            description = "Boot timeout seconds";
          };
          maxGenerations = lib.mkOption {
            type = lib.types.ints.positive;
            default = 10;
            description = "Max NixOS generations to keep in boot menu";
          };
          resolution = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "1920x1080";
            description = "Screen resolution (null = firmware default)";
          };
          theme = lib.mkOption {
            type = lib.types.nullOr lib.types.package;
            default = null;
            description = "rEFInd theme package (e.g. pkgs.refind-theme-minimal)";
          };
          hideUI = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "hints"
              "arrows"
              "label"
              "badges"
            ];
            description = "UI elements to hide";
          };
          showTools = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "shutdown"
              "reboot"
              "firmware"
            ];
            description = "Tool entries to show";
          };
          extraEntries = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = [ ];
            description = "Manual boot entries (name, loader, ostype, etc.)";
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
            description = "Systemd initrd for Plymouth";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        boot.initrd.systemd.enable = cfg.initrd.enable;

        # Systemd-boot (explicitly false when using another loader)
        boot.loader.systemd-boot.enable = cfg.loader == "systemd-boot" && !cfg.secureBoot.enable;
        boot.loader.systemd-boot.configurationLimit = lib.mkIf (cfg.loader == "systemd-boot") 10;
        boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
        boot.loader.timeout = lib.mkDefault cfg.refind.timeout;

        # rEFInd
        boot.loader.refind = lib.mkIf (cfg.loader == "refind") {
          enable = true;
          inherit (cfg.refind)
            timeout
            maxGenerations
            resolution
            theme
            hideUI
            showTools
            ;
        };

        # GRUB
        boot.loader.grub.enable = lib.mkIf (cfg.loader == "grub") true;

        # Secure Boot (Lanzaboote)
        boot.lanzaboote.enable = lib.mkIf cfg.secureBoot.enable true;
        boot.lanzaboote.pkiBundle = lib.mkIf cfg.secureBoot.enable cfg.secureBoot.pkiBundle;

        # Plymouth
        boot.plymouth.enable = lib.mkIf cfg.plymouth.enable true;
        boot.plymouth.theme = lib.mkIf cfg.plymouth.enable cfg.plymouth.theme;

        # Console resolution (systemd-boot only)
        boot.loader.systemd-boot.consoleMode = lib.mkIf (
          cfg.loader == "systemd-boot" && cfg.consoleMode != null
        ) cfg.consoleMode;

        # Kernel parameters for clean boot
        boot.kernelParams = lib.optionals cfg.plymouth.enable [
          "quiet"
          "splash"
          "rd.systemd.show_status=false"
          "rd.udev.log_level=3"
          "udev.log_priority=3"
        ];

        environment.systemPackages = [
          pkgs.efibootmgr
        ]
        ++ lib.optionals cfg.secureBoot.enable [ pkgs.sbctl ];
      };
    };
in
{
  flake.modules.nixos.boot-loader = mod;
}

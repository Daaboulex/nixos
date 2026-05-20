# loader — boot manager composition (systemd-boot + rEFInd + GRUB), Plymouth, initrd.
#
# Bootloaders are INDEPENDENT enable flags — hosts can mix as needed.
# Typical patterns:
#   - Plain Linux host:    systemdBoot.enable = true
#   - Lanzaboote secured:  systemdBoot.enable = true + secureBoot.enable = true
#   - Mac (Apple firmware): refind.enable = true (efiInstallAsRemovable + extraEntries)
#                           + systemdBoot.enable = true (handles NixOS gens; rEFInd chainloads it)
#   - GRUB-only:           grub.enable = true
#
# When both refind.enable and systemdBoot.enable are true, refind-nix's
# allowCoexistWithSystemdBoot is auto-set so the upstream module's
# defensive mutex relaxes. The two installers don't fight over a single
# attribute (refind-nix wires through boot.loader.external.installHook,
# systemd-boot wires through its own install path) — each runs on every
# `nixos-rebuild switch`, both menus stay fresh.
#
# Hosts using the hybrid declare the chainload directly via refind-nix's
# extraEntries option (documented refind-nix API — no custom wrapper).
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

        systemdBoot.enable = lib.mkEnableOption "systemd-boot";
        grub.enable = lib.mkEnableOption "GRUB";

        secureBoot = {
          enable = lib.mkEnableOption "Lanzaboote secure boot (replaces systemd-boot install path)";
          pkiBundle = lib.mkOption {
            type = lib.types.path;
            default = "/var/lib/sbctl";
            description = "Path to PKI bundle";
          };
        };

        refind = {
          enable = lib.mkEnableOption "rEFInd boot manager";

          efiInstallAsRemovable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Install rEFInd at `/EFI/BOOT/BOOTx64.EFI` (the EFI firmware
              fallback path) instead of `/EFI/refind/refind_x64.efi` +
              NVRAM entry. Set true on hardware whose firmware ignores or
              resets `BootOrder` — notably Apple Macs. The fallback path
              wins regardless of NVRAM state.
            '';
          };

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
            description = "Manual boot entries (passed through to refind-nix)";
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

        # Systemd-boot — Lanzaboote replaces the install path when secure
        # boot is on, so guard against double-install.
        boot.loader.systemd-boot.enable = cfg.systemdBoot.enable && !cfg.secureBoot.enable;
        boot.loader.systemd-boot.configurationLimit = lib.mkIf cfg.systemdBoot.enable 10;
        boot.loader.systemd-boot.consoleMode = lib.mkIf (
          cfg.systemdBoot.enable && cfg.consoleMode != null
        ) cfg.consoleMode;

        boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
        boot.loader.timeout = lib.mkDefault cfg.refind.timeout;

        # rEFInd — auto-opt-in to refind-nix's coexistence flag when
        # systemd-boot is also enabled (relaxes refind-nix's defensive
        # mutex assertion). Hosts declare chainload entries via
        # refind.extraEntries — passed straight through to refind-nix.
        boot.loader.refind = lib.mkIf cfg.refind.enable {
          enable = true;
          inherit (cfg.refind)
            timeout
            maxGenerations
            resolution
            theme
            hideUI
            showTools
            efiInstallAsRemovable
            extraEntries
            ;
          allowCoexistWithSystemdBoot = cfg.systemdBoot.enable;
        };

        # GRUB
        boot.loader.grub.enable = lib.mkIf cfg.grub.enable true;

        # Secure Boot (Lanzaboote — takes over the systemd-boot install slot)
        boot.lanzaboote.enable = lib.mkIf cfg.secureBoot.enable true;
        boot.lanzaboote.pkiBundle = lib.mkIf cfg.secureBoot.enable cfg.secureBoot.pkiBundle;

        # Plymouth
        boot.plymouth.enable = lib.mkIf cfg.plymouth.enable true;
        boot.plymouth.theme = lib.mkIf cfg.plymouth.enable cfg.plymouth.theme;

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

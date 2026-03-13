{ inputs, withSystem, ... }:
{
  flake.nixosModules.diagnostics-corecycler =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.diagnostics.corecycler;
      perSystem = withSystem pkgs.stdenv.hostPlatform.system ({ inputs', ... }: inputs');
      package =
        if cfg.unfreeBackends then
          perSystem.linux-corecycler.packages.full
        else
          perSystem.linux-corecycler.packages.default;
      zenpower = pkgs.callPackage ./zenpower.nix {
        inherit (config.boot.kernelPackages) kernel;
      };
      ryzenSmuPkg = pkgs.callPackage ./ryzen-smu.nix {
        inherit (config.boot.kernelPackages) kernel;
      };
    in
    {
      _class = "nixos";

      options.myModules.diagnostics.corecycler = {
        enable = lib.mkEnableOption "CoreCyclerLx per-core CPU stability tester and PBO Curve Optimizer tuner";
        unfreeBackends = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to include unfree backends (mprime). When false, only FOSS backends (stress-ng) are bundled.";
        };
        ryzenSmu = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to load the ryzen_smu kernel module for Curve Optimizer read/write via SMU";
        };
        zenpower = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to use zenpower3 instead of k10temp for Vcore/Vsoc voltage monitoring via SVI2. Replaces k10temp (blacklisted).";
        };
        deviceAccess = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to grant primaryUser access to MSR devices and SMU sysfs via a dedicated group and udev rules. No sudo required.";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ package ];

        # --- Device access via dedicated group (no sudo) ---
        # Creates a 'corecycler' group, adds primaryUser to it, then:
        # - udev rule: /dev/cpu/*/msr readable by group
        # - tmpfiles: /sys/kernel/ryzen_smu_drv/* writable by group
        # - dmesg unrestricted so MCE detection works without root
        users.groups.corecycler = lib.mkIf cfg.deviceAccess { };
        users.users.${config.myModules.primaryUser}.extraGroups = lib.mkIf cfg.deviceAccess [
          "corecycler"
        ];

        # MSR devices: grant group read access for APERF/MPERF (clock stretch)
        # and RAPL energy counters (per-core + package power)
        services.udev.extraRules = lib.mkIf cfg.deviceAccess ''
          SUBSYSTEM=="msr", KERNEL=="msr[0-9]*", GROUP="corecycler", MODE="0640"
        '';

        # Ensure msr kernel module is loaded so /dev/cpu/*/msr exists
        boot.kernelModules = [
          "msr"
        ]
        ++ lib.optional cfg.ryzenSmu "ryzen_smu"
        ++ lib.optional cfg.zenpower "zenpower";

        # SMU sysfs: grant group read/write for Curve Optimizer access
        # tmpfiles sets permissions after ryzen_smu creates the sysfs entries
        systemd.tmpfiles.rules = lib.mkIf (cfg.deviceAccess && cfg.ryzenSmu) [
          "z /sys/kernel/ryzen_smu_drv/smu_args 0660 root corecycler - -"
          "z /sys/kernel/ryzen_smu_drv/mp1_smu_cmd 0660 root corecycler - -"
          "z /sys/kernel/ryzen_smu_drv/rsmu_cmd 0660 root corecycler - -"
        ];

        # Allow unprivileged dmesg access for MCE error detection
        boot.kernel.sysctl = lib.mkIf cfg.deviceAccess {
          "kernel.dmesg_restrict" = lib.mkDefault 0;
        };

        # Out-of-tree kernel modules — custom derivations that build with
        # clang for CachyOS LTO kernels, gcc otherwise
        boot.extraModulePackages =
          lib.optional cfg.ryzenSmu ryzenSmuPkg ++ lib.optional cfg.zenpower zenpower;
        boot.blacklistedKernelModules = lib.mkIf cfg.zenpower [ "k10temp" ];
      };
    };
}

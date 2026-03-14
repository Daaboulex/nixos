# CoreCyclerLx — per-core CPU stability tester and PBO Curve Optimizer tuner.
#
# This module handles the application and device access ONLY.
# Kernel modules (ryzen_smu, zenpower, nct6775, it87) are owned by
# hardware modules (cpu-amd, sensors) — enable them there.
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
        deviceAccess = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to grant primaryUser access to MSR devices and SMU sysfs via a dedicated group and udev rules. No sudo required for monitoring and CO access.";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ package ];

        # --- Device access via dedicated group (no sudo) ---
        # Creates a 'corecycler' group, adds primaryUser to it, then:
        # - udev rule: /dev/cpu/*/msr readable by group
        # - tmpfiles: /sys/kernel/ryzen_smu_drv/* writable by group (if ryzen_smu loaded)
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

        # SMU sysfs: grant group read/write for Curve Optimizer access.
        # These rules are harmless if ryzen_smu is not loaded — tmpfiles 'z' type
        # silently skips non-existent paths.
        systemd.tmpfiles.rules = lib.mkIf cfg.deviceAccess [
          "z /sys/kernel/ryzen_smu_drv/smu_args 0660 root corecycler - -"
          "z /sys/kernel/ryzen_smu_drv/mp1_smu_cmd 0660 root corecycler - -"
          "z /sys/kernel/ryzen_smu_drv/rsmu_cmd 0660 root corecycler - -"
        ];

        # Allow unprivileged dmesg access for MCE error detection
        boot.kernel.sysctl = lib.mkIf cfg.deviceAccess {
          "kernel.dmesg_restrict" = lib.mkDefault 0;
        };
      };
    };
}

# corecycler — CoreCyclerLx device access (MSR, SMU sysfs, dmesg) for Curve Optimizer stability testing.
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
      cfg = config.myModules.tuning.corecycler;
      smuLoadedSentinel = "/sys/kernel/ryzen_smu_drv/smu_args";
      smuFileArgs = lib.concatStringsSep " " [
        smuLoadedSentinel
        "/sys/kernel/ryzen_smu_drv/mp1_smu_cmd"
        "/sys/kernel/ryzen_smu_drv/rsmu_cmd"
        "/sys/kernel/ryzen_smu_drv/smn"
      ];
    in
    {
      _class = "nixos";

      options.myModules.tuning.corecycler = {
        enable = lib.mkEnableOption "CoreCyclerLx device access (MSR, SMU sysfs, dmesg)";
        deviceAccess = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to grant primaryUser access to MSR devices and SMU sysfs via a dedicated group, a udev rule for MSR and a oneshot for the ryzen_smu files. No sudo required for monitoring and CO access. The oneshot includes `smn`, which is arbitrary SMN register access — grant it only to a user already trusted with the SMU mailbox.";
        };
      };

      config = lib.mkIf cfg.enable {
        # --- Device access via dedicated group (no sudo) ---
        # Creates a 'corecycler' group, adds primaryUser to it, then:
        # - udev rule: /dev/cpu/*/msr readable by group
        # - oneshot after module load: /sys/kernel/ryzen_smu_drv/* writable by group
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

        systemd.services.corecycler-smu-permissions = lib.mkIf cfg.deviceAccess {
          description = "Grant the corecycler group access to the ryzen_smu sysfs files";
          after = [ "systemd-modules-load.service" ];
          wantedBy = [ "multi-user.target" ];
          unitConfig.ConditionPathExists = smuLoadedSentinel;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = [
              "${pkgs.coreutils}/bin/chgrp corecycler ${smuFileArgs}"
              "${pkgs.coreutils}/bin/chmod 0660 ${smuFileArgs}"
            ];
          };
        };

        # Allow unprivileged dmesg access for MCE error detection (matches the
        # corecycler upstream module and SECURITY.md). mkDefault so a host can
        # re-restrict to 1 if it does not need corecycler's dmesg MCE path.
        boot.kernel.sysctl = lib.mkIf cfg.deviceAccess {
          "kernel.dmesg_restrict" = lib.mkDefault 0;
        };
      };
    };
in
{
  flake.modules.nixos.tuning-corecycler = mod;
}

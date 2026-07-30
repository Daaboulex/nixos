# cpu-intel — Intel CPU optimizations (microcode, intel_pstate, governor).
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
      cfg = config.myModules.hardware.cpuIntel;
    in
    {
      _class = "nixos";
      options.myModules.hardware.cpuIntel = {
        enable = lib.mkEnableOption "Intel CPU optimizations";

        pstate = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Intel P-State driver for modern power management";
          };
          mode = lib.mkOption {
            type = lib.types.enum [
              "active"
              "passive"
              "no_hwp"
            ];
            default = "active";
            description = "Intel P-State mode (active recommended for Haswell+)";
          };
        };

        kvm = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "KVM-Intel virtualization support (VT-x)";
          };
        };

        updateMicrocode = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Update Intel CPU microcode";
        };

        iommu = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Intel IOMMU (VT-d) for device passthrough";
          };
        };

        undervolt = {
          enable = lib.mkEnableOption ''
            MSR voltage-offset undervolting via `services.undervolt` (lower voltage
            -> cooler -> higher sustained boost; never caps clocks). On firmware
            carrying the Plundervolt mitigation (CVE-2019-11157) the voltage MSR
            (0x150) is locked and the offsets silently no-op -- harmless. Requires
            the `msr` kernel module (myModules.sensors.msr.enable). The RAPL power
            limits and temp target below are SEPARATE opt-ins, off by default
            because they can CAP performance (see their warnings)
          '';
          coreOffset = lib.mkOption {
            type = lib.types.int;
            default = 0;
            description = "CPU core (and cache) voltage offset in mV; negative undervolts. Does not cap performance.";
          };
          gpuOffset = lib.mkOption {
            type = lib.types.int;
            default = 0;
            description = "iGPU voltage offset in mV; negative undervolts. Does not cap performance.";
          };
          tempLimit = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = ''
              Thermal throttle target in degrees C (null = leave to thermald +
              firmware, the recommended default). Setting it adds a SECOND thermal
              master alongside thermald (auto-on for Intel via hardware.core);
              prefer null and let thermald manage.
            '';
          };
          powerLimit = {
            p1 = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = ''
                RAPL PL1 sustained package power in W (null = unset, the safe
                default). WARNING -- RAPL is lowest-limit-wins: a static value can
                only hold the CPU AT-OR-BELOW the firmware/EC budget, never raise
                it, so a too-low value silently CAPS sustained performance. Leave
                null to let the firmware/EC + thermald manage dynamically. Set it
                only to deliberately LOWER power (quiet/cool), or to RAISE knowing a
                resetting EC may need useTimer / an MMIO lock-bit to hold it.
              '';
            };
            p2 = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "RAPL PL2 short-burst package power in W (null = unset). Same lowest-wins capping caveat as p1.";
            };
          };
        };
      };

      config = lib.mkIf cfg.enable {
        boot.kernelParams = lib.concatLists [
          (lib.optionals cfg.pstate.enable [ "intel_pstate=${cfg.pstate.mode}" ])
          (lib.optionals cfg.iommu.enable [
            "intel_iommu=on"
            "iommu=pt"
          ])
          (lib.optionals (!cfg.iommu.enable) [ "intel_iommu=off" ])
        ];

        boot.kernelModules = lib.concatLists [
          [ "coretemp" ]
          (lib.optionals cfg.kvm.enable [ "kvm-intel" ])
        ];

        # Expose /dev/kvm to the nix build sandbox when KVM is on -- single owner of
        # this path (the precondition is kvm.enable, which this module owns).
        nix.settings.extra-sandbox-paths = lib.mkIf cfg.kvm.enable [ "/dev/kvm" ];

        hardware.cpu.intel.updateMicrocode = cfg.updateMicrocode;
        # Frequency governor is owned solely by myModules.tuning.performance
        # (its mkDefault is the single source of truth); do not also write it
        # here -- a second writer made one definition silently dead.

        # Undervolt + RAPL power limits. services.undervolt writes the voltage
        # MSR (0x150, often locked by the Plundervolt mitigation) AND the RAPL
        # power-limit MSRs (not locked). useTimer re-applies if the EC resets the
        # values. The `msr` module is provided by myModules.sensors.msr.
        services.undervolt = lib.mkIf cfg.undervolt.enable (
          {
            enable = true;
            coreOffset = cfg.undervolt.coreOffset; # the tool applies this to cache too
            gpuOffset = cfg.undervolt.gpuOffset;
            useTimer = true;
          }
          // lib.optionalAttrs (cfg.undervolt.tempLimit != null) {
            temp = cfg.undervolt.tempLimit;
          }
          // lib.optionalAttrs (cfg.undervolt.powerLimit.p1 != null) {
            p1 = {
              limit = cfg.undervolt.powerLimit.p1;
              window = 28.0;
            };
          }
          // lib.optionalAttrs (cfg.undervolt.powerLimit.p2 != null) {
            p2 = {
              limit = cfg.undervolt.powerLimit.p2;
              window = 0.002;
            };
          }
        );
      };
    };
in
{
  flake.modules.nixos.hardware-cpu-intel = mod;

}

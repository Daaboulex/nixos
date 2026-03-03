{ inputs, ... }: {
  flake.nixosModules.hardware-cpu-amd = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.hardware.cpu.amd;
    in {
      options.myModules.hardware.cpu.amd = {
        enable = lib.mkEnableOption "AMD CPU optimizations";

        pstate = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable AMD P-State driver for modern power management";
          };
          mode = lib.mkOption {
            type = lib.types.enum [ "active" "passive" "guided" ];
            default = "active";
            description = "AMD P-State mode (active recommended for Zen 3+)";
          };
        };

        prefcore = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable AMD Preferred Core technology";
          };
        };

        x3dVcache = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable AMD 3D V-Cache optimizer (for dual-CCD X3D processors like 9950X3D/9900X3D)";
          };
          mode = lib.mkOption {
            type = lib.types.enum [ "cache" "frequency" ];
            default = "cache";
            description = ''
              3D V-Cache scheduling preference:
              - "cache": prefer CCD with larger L3 cache (gaming, cache-sensitive workloads)
              - "frequency": prefer CCD with higher clocks (productivity, compilation)
              Requires BIOS CPPC option set to "Driver".
            '';
          };
        };

        kvm = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable KVM-AMD virtualization support";
          };
        };

        updateMicrocode = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Update AMD CPU microcode";
        };
      };

      config = lib.mkIf cfg.enable {
        boot.kernelParams = lib.concatLists [
          (lib.optionals cfg.pstate.enable [ "amd_pstate=${cfg.pstate.mode}" ])
          (lib.optionals cfg.prefcore.enable [ "amd_prefcore=enable" ])
        ];

        boot.kernelModules = lib.concatLists [
          [ "k10temp" ]
          (lib.optionals cfg.kvm.enable [ "kvm-amd" ])
          (lib.optionals cfg.x3dVcache.enable [ "amd_3d_vcache" ])
        ];

        # Set 3D V-Cache mode via module parameter — the driver's own x3d_mode param
        # sets the initial mode at load time, no sysfs write needed
        boot.extraModprobeConfig = lib.mkIf cfg.x3dVcache.enable ''
          options amd_3d_vcache x3d_mode=${cfg.x3dVcache.mode}
        '';

        hardware.cpu.amd.updateMicrocode = cfg.updateMicrocode;
      };
    };
}

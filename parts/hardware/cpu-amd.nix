{ inputs, ... }:
{
  flake.nixosModules.hardware-cpu-amd =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.hardware.cpu.amd;
      zenpowerPkg = pkgs.callPackage ./zenpower.nix {
        inherit (config.boot.kernelPackages) kernel;
      };
      ryzenSmuPkg = pkgs.callPackage ./ryzen-smu.nix {
        inherit (config.boot.kernelPackages) kernel;
      };
    in
    {
      _class = "nixos";
      options.myModules.hardware.cpu.amd = {
        enable = lib.mkEnableOption "AMD CPU optimizations";

        pstate = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "AMD P-State driver for modern power management";
          };
          mode = lib.mkOption {
            type = lib.types.enum [
              "active"
              "passive"
              "guided"
            ];
            default = "active";
            description = "AMD P-State mode (active recommended for Zen 3+)";
          };
        };

        prefcore = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "AMD Preferred Core technology";
          };
        };

        x3dVcache = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "AMD 3D V-Cache optimizer (for dual-CCD X3D processors like 9950X3D/9900X3D)";
          };
          mode = lib.mkOption {
            type = lib.types.enum [
              "cache"
              "frequency"
            ];
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
            description = "KVM-AMD virtualization support";
          };
        };

        updateMicrocode = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Update AMD CPU microcode";
        };

        # --- Monitoring & SMU kernel modules ---

        zenpower = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Load zenpower5 instead of k10temp for AMD CPU monitoring. Provides Tctl/Tdie/Tccd temps, SVI2 voltage/current (Zen 1-4), and RAPL package power. Replaces k10temp (blacklisted). Zen 1 through Zen 5.";
        };

        ryzenSmu = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Load the ryzen_smu kernel module (amkillam fork) for AMD SMU access. Required for Curve Optimizer read/write, PBO limits, boost override. Zen 1 through Zen 5.";
        };
      };

      config = lib.mkIf cfg.enable {
        boot.kernelParams = lib.concatLists [
          (lib.optionals cfg.pstate.enable [ "amd_pstate=${cfg.pstate.mode}" ])
          (lib.optionals cfg.prefcore.enable [ "amd_prefcore=enable" ])
        ];

        boot.kernelModules = lib.concatLists [
          # k10temp is the default AMD temp driver — zenpower replaces it
          (lib.optionals (!cfg.zenpower) [ "k10temp" ])
          (lib.optionals cfg.zenpower [ "zenpower" ])
          (lib.optionals cfg.ryzenSmu [ "ryzen_smu" ])
          (lib.optionals cfg.kvm.enable [ "kvm-amd" ])
          (lib.optionals cfg.x3dVcache.enable [ "amd_3d_vcache" ])
        ];

        # Out-of-tree kernel modules — custom derivations with Clang/LTO support
        boot.extraModulePackages =
          lib.optional cfg.zenpower zenpowerPkg ++ lib.optional cfg.ryzenSmu ryzenSmuPkg;

        # zenpower and k10temp conflict — they use the same PCI device
        boot.blacklistedKernelModules = lib.mkIf cfg.zenpower [ "k10temp" ];

        # Set 3D V-Cache mode via module parameter — the driver's own x3d_mode param
        # sets the initial mode at load time, no sysfs write needed
        boot.extraModprobeConfig = lib.mkIf cfg.x3dVcache.enable ''
          options amd_3d_vcache x3d_mode=${cfg.x3dVcache.mode}
        '';

        hardware.cpu.amd.updateMicrocode = cfg.updateMicrocode;
      };
    };
}

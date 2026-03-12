{ inputs, ... }:
{
  flake.nixosModules.hardware-cpu-intel =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.hardware.cpu.intel;
    in
    {
      _class = "nixos";
      options.myModules.hardware.cpu.intel = {
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

        governor = lib.mkOption {
          type = lib.types.enum [
            "performance"
            "powersave"
            "schedutil"
            "ondemand"
            "conservative"
          ];
          default = "powersave";
          description = "CPU frequency governor (powersave recommended for laptops with P-State)";
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

        hardware.cpu.intel.updateMicrocode = cfg.updateMicrocode;

        powerManagement.cpuFreqGovernor = lib.mkOptionDefault cfg.governor;
      };
    };
}

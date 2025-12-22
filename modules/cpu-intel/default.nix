{ config, pkgs, lib, ... }:

let
  cfg = config.myModules.hardware.cpu.intel;
in {
  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.hardware.cpu.intel = {
    enable = lib.mkEnableOption "Intel CPU optimizations";
    
    pstate = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Intel P-State driver for modern power management";
      };
      mode = lib.mkOption {
        type = lib.types.enum [ "active" "passive" "no_hwp" ];
        default = "active";
        description = "Intel P-State mode (active recommended for Haswell+)";
      };
    };
    
    governor = lib.mkOption {
      type = lib.types.enum [ "performance" "powersave" "schedutil" "ondemand" "conservative" ];
      default = "powersave";
      description = "CPU frequency governor (powersave recommended for laptops with P-State)";
    };
    
    kvm = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable KVM-Intel virtualization support (VT-x)";
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
        description = "Enable Intel IOMMU (VT-d) for device passthrough";
      };
    };
  };

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Kernel Parameters
    # --------------------------------------------------------------------------
    boot.kernelParams = lib.concatLists [
      # Intel P-State driver
      (lib.optionals cfg.pstate.enable [
        "intel_pstate=${cfg.pstate.mode}"
      ])
      # Intel IOMMU
      (lib.optionals cfg.iommu.enable [
        "intel_iommu=on"
        "iommu=pt"
      ])
      (lib.optionals (!cfg.iommu.enable) [
        "intel_iommu=off"
      ])
    ];
    
    # --------------------------------------------------------------------------
    # Kernel Modules
    # --------------------------------------------------------------------------
    boot.kernelModules = lib.concatLists [
      # Temperature monitoring
      [ "coretemp" ]
      # KVM Virtualization
      (lib.optionals cfg.kvm.enable [ "kvm-intel" ])
    ];
    
    # --------------------------------------------------------------------------
    # CPU Microcode
    # --------------------------------------------------------------------------
    hardware.cpu.intel.updateMicrocode = cfg.updateMicrocode;
    
    # --------------------------------------------------------------------------
    # CPU Governor
    # CPU governor - low priority so performance module can override
    powerManagement.cpuFreqGovernor = lib.mkOptionDefault cfg.governor;
  };
}

# ==============================================================================
# Intel CPU Module
# ==============================================================================
# This module consolidates all Intel CPU-specific configuration.
# 
# When enabled via myModules.hardware.cpu.intel.enable = true, it will:
#   - Set intel_pstate kernel parameter (active mode by default)
#   - Load coretemp for temperature monitoring
#   - Load kvm-intel for virtualization support
#   - Update Intel CPU microcode
#   - Set CPU governor to powersave (optimal for laptops with P-State)
#
# Host config should only need:
#   myModules.hardware.cpu.intel.enable = true;
#
# To customize:
#   myModules.hardware.cpu.intel.governor = "schedutil";
#   myModules.hardware.cpu.intel.iommu.enable = true;  # For GPU passthrough
# ==============================================================================

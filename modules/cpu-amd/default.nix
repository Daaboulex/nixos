{ config, pkgs, lib, ... }:

let
  cfg = config.myModules.hardware.cpu.amd;
in {
  # ============================================================================
  # Module Options
  # ============================================================================
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
    
    # Governor is handled by myModules.hardware.performance module
    # (performance.nix sets it based on profile: performance/balanced/laptop)
    
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

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Kernel Parameters
    # --------------------------------------------------------------------------
    boot.kernelParams = lib.concatLists [
      # AMD P-State driver
      (lib.optionals cfg.pstate.enable [
        "amd_pstate=${cfg.pstate.mode}"
      ])
      # Preferred Core
      (lib.optionals cfg.prefcore.enable [
        "amd_prefcore=enable"
      ])
    ];
    
    # --------------------------------------------------------------------------
    # Kernel Modules
    # --------------------------------------------------------------------------
    boot.kernelModules = lib.concatLists [
      # Temperature monitoring
      [ "k10temp" ]
      # KVM Virtualization
      (lib.optionals cfg.kvm.enable [ "kvm-amd" ])
    ];
    
    # --------------------------------------------------------------------------
    # CPU Microcode
    # --------------------------------------------------------------------------
    hardware.cpu.amd.updateMicrocode = cfg.updateMicrocode;
    
    # Note: CPU governor is set by myModules.hardware.performance module
  };
}

# ==============================================================================
# AMD CPU Module
# ==============================================================================
# This module consolidates all AMD CPU-specific configuration.
# 
# When enabled via myModules.hardware.cpu.amd.enable = true, it will:
#   - Set amd_pstate kernel parameter (active mode by default)
#   - Enable AMD Preferred Core technology
#   - Load k10temp for temperature monitoring
#   - Load kvm-amd for virtualization support
#   - Update AMD CPU microcode
#   - Set CPU governor to schedutil (optimal for gaming)
#
# Host config should only need:
#   myModules.hardware.cpu.amd.enable = true;
#
# To customize:
#   myModules.hardware.cpu.amd.governor = "performance";
#   myModules.hardware.cpu.amd.pstate.mode = "guided";
# ==============================================================================

{ config, pkgs, lib, ... }:

let
  cfg = config.myModules.hardware.graphics.amd;
in {
  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.hardware.graphics.amd = {
    enable = lib.mkEnableOption "AMD Graphics configuration";
    
    lact = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable LACT daemon for AMD GPU control/overclocking";
      };
    };
    
    enablePPFeatureMask = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable full AMD GPU power management features (ppfeaturemask=0xffffffff)";
    };
  };

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # GPU Kernel Module
    # --------------------------------------------------------------------------
    boot.kernelModules = [ "amdgpu" ];
    
    # --------------------------------------------------------------------------
    # GPU Kernel Parameters
    # --------------------------------------------------------------------------
    boot.kernelParams = lib.optionals cfg.enablePPFeatureMask [
      "amdgpu.ppfeaturemask=0xffffffff"
    ];
    
    # --------------------------------------------------------------------------
    # Video Drivers
    # --------------------------------------------------------------------------
    services.xserver.videoDrivers = [ "amdgpu" ];
    
    # --------------------------------------------------------------------------
    # LACT - AMD GPU Control Daemon
    # --------------------------------------------------------------------------
    environment.systemPackages = lib.mkIf cfg.lact.enable (with pkgs; [
      lact
      corectrl
    ]);
    
    systemd.services.lact = lib.mkIf cfg.lact.enable {
      description = "AMDGPU Control Daemon";
      after = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.lact}/bin/lact daemon";
      };
    };
    
    # --------------------------------------------------------------------------
    # Firmware
    # --------------------------------------------------------------------------
    hardware.enableRedistributableFirmware = true;
  };
}

# ==============================================================================
# AMD Graphics Module
# ==============================================================================
# GPU-only settings. CPU settings (microcode, kvm-amd, k10temp) are now in
# modules/hardware/cpu/amd.nix
# ==============================================================================

# ==============================================================================
# AMD Graphics Module
# ==============================================================================
# This module consolidates all AMD-specific graphics and CPU configuration.
# 
# When enabled via myModules.hardware.graphics.amd.enable = true, it will:
#   - Load amdgpu, kvm-amd, k10temp kernel modules
#   - Set amdgpu.ppfeaturemask for full feature access
#   - Configure xserver to use amdgpu driver
#   - Update AMD CPU microcode
#   - Install and enable LACT daemon for GPU control
#   - Enable redistributable firmware
#
# Host config should only need:
#   myModules.hardware.graphics.amd.enable = true;
#
# To disable specific features:
#   myModules.hardware.graphics.amd.lact.enable = false;
#   myModules.hardware.graphics.amd.enablePPFeatureMask = false;
# ==============================================================================
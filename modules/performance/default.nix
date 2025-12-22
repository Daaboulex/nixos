{ config, pkgs, lib, ... }:

let
  cfg = config.myModules.hardware.performance;
  cachyosCfg = config.myModules.cachyos.settings;
in
{
  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.hardware.performance = {
    enable = lib.mkEnableOption "Performance tuning and optimization";

    governor = lib.mkOption {
      type = lib.types.str;
      default = "powersave"; 
      description = ''
        CPU frequency governor to use. 
        For modern AMD (amd-pstate) and Intel CPUs, 'powersave' is typically verified 
        to work best as it allows the hardware to manage frequency via EPP.
      '';
    };

    zramPercent = lib.mkOption {
      type = lib.types.int;
      default = 75;
      description = "Percentage of RAM to use for ZRAM swap (0-100).";
    };

    ananicy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Ananicy (auto nice/renice daemon) with CachyOS rules.";
    };
  };

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf cfg.enable {
    # ==========================================================================
    # Zram Swap - Compressed RAM-based Swap
    # ==========================================================================
    # Only enable manual ZRAM if CachyOS settings are NOT enabled.
    # CachyOS module provides its own optimized ZRAM config (100% size, zstd).
    zramSwap = lib.mkIf (!cachyosCfg.enable) {
      enable = lib.mkDefault true;
      algorithm = "zstd";  # Fast compression algorithm
      memoryPercent = cfg.zramPercent;
      priority = lib.mkDefault 100;
    };

    # Ensure swappiness takes advantage of ZRAM
    # Only apply if CachyOS is NOT enabled (it sets its own sysctls)
    boot.kernel.sysctl = lib.mkIf (!cachyosCfg.enable) {
      "vm.swappiness" = 133;
      "vm.watermark_boost_factor" = 0;
      "vm.watermark_scale_factor" = 125;
      "vm.page-cluster" = 0;
    };

    # ==========================================================================
    # CPU Frequency Governor
    # ==========================================================================
    powerManagement.cpuFreqGovernor = lib.mkDefault cfg.governor;

    # ==========================================================================
    # Ananicy - Process Priority Manager
    # ==========================================================================
    services.ananicy = {
      enable = cfg.ananicy;
      package = pkgs.ananicy-cpp;
      rulesProvider = pkgs.ananicy-rules-cachyos_git;
    };
  };
}
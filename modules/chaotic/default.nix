{ config, pkgs, lib, ... }:

{
  imports = [ ./optimizations.nix ];

  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.chaotic.gaming = {
    enable = lib.mkEnableOption "Chaotic-Nyx gaming optimizations";
    
    enableGamescope = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Gamescope compositor (SteamOS session compositor)";
    };
    
    enableMangohud = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable MangoHud performance overlay";
    };
    
    enableProtonCachyOS = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Proton-CachyOS for better game compatibility";
    };
    
    cpuMicroarch = lib.mkOption {
      type = lib.types.enum [ "generic" "v2" "v3" "v4" ];
      default = "v3";
      description = ''
        CPU microarchitecture level for optimized builds:
        - generic: Standard x86_64
        - v2: Older CPUs (2009+)
        - v3: Modern CPUs (Ryzen, Haswell+) - Recommended
        - v4: Latest CPUs (Zen 4, Alder Lake+)
      '';
    };
  };

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf config.myModules.chaotic.gaming.enable (let
    cfg = config.myModules.chaotic.gaming;
    
    # Select Proton package based on microarchitecture
    protonPackage = 
      if cfg.cpuMicroarch == "v4" then pkgs.proton-cachyos_x86_64_v4
      else if cfg.cpuMicroarch == "v3" then pkgs.proton-cachyos_x86_64_v3
      else if cfg.cpuMicroarch == "v2" then pkgs.proton-cachyos_x86_64_v2
      else pkgs.proton-cachyos;
  in {
    # ==========================================================================
    # Overlay for Gamescope and MangoHud Git versions
    # ==========================================================================
    nixpkgs.overlays = [
      (final: prev: {
        gamescope = if cfg.enableGamescope then prev.gamescope_git else prev.gamescope;
        mangohud = if cfg.enableMangohud then prev.mangohud_git else prev.mangohud;
      })
    ];

    # ==========================================================================
    # Steam Compatibility Packages (Proton)
    # ==========================================================================
    programs.steam.extraCompatPackages = lib.mkIf cfg.enableProtonCachyOS [
      pkgs.proton-ge-custom
      protonPackage
    ];

    # ==========================================================================
    # Gaming Packages
    # ==========================================================================
    environment.systemPackages = with pkgs; [
      # Gamescope - SteamOS session compositor (uses overlay)
      (lib.mkIf cfg.enableGamescope gamescope)
      
      # MangoHud - Performance overlay (uses overlay)
      (lib.mkIf cfg.enableMangohud mangohud)
      
      # LatencyFleX - Vulkan layer for reduced input latency
      latencyflex-vulkan
      
      # Luxtorpeda - Run games using native Linux engines
      luxtorpeda
      
      # Ananicy rules for process priority optimization
      ananicy-rules-cachyos_git
      
      # Lan-Mouse - Software KVM
      #lan-mouse_git #TODO make sure this is a config option or something remote play gaming config opption.
      
      # Desktop aesthetics from Chaotic-Nyx
      beautyline-icons
      applet-window-title
    ];

    # ==========================================================================
    # Gaming-Specific System Configuration
    # ==========================================================================
    
    # Enable GameMode for automatic performance optimizations
    programs.gamemode = {
      enable = true;
      settings = {
        general = {
          renice = 10;  # Renice game processes
        };
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
          amd_performance_level = "high";
        };
      };
    };

    # ==========================================================================
    # Gaming Environment Variables
    # ==========================================================================
    environment.sessionVariables = {
      # MangoHud disabled by default (enable per-app with MANGOHUD=1)
      MANGOHUD = lib.mkDefault "0";
      
      # Enable Gamescope frame limiter
      GAMESCOPE_LIMITER_FILE = "/tmp/gamescope-limiter";
      
      # AMD-specific optimizations
      AMD_VULKAN_ICD = lib.mkDefault "RADV";
      RADV_PERFTEST = "gpl,nggc";  # Enable GPL and NGG culling
      
      # Enable Vulkan layers
      VK_LAYER_PATH = "/run/opengl-driver/share/vulkan/explicit_layer.d";
    };

    # ==========================================================================
    # System Tweaks for Gaming
    # ==========================================================================
    
    # Increase file descriptor limits for games
    security.pam.loginLimits = [
      {
        domain = "*";
        type = "soft";
        item = "nofile";
        value = "524288";
      }
      {
        domain = "*";
        type = "hard";
        item = "nofile";
        value = "1048576";
      }
    ];

    # Enable esync/fsync for better game performance
    systemd.settings.Manager.DefaultLimitNOFILE = "1048576";

    # Optimize I/O scheduler for gaming (if using SSD)
    services.udev.extraRules = ''
      # Set I/O scheduler to 'none' for NVMe devices (best for gaming)
      # Pattern nvme[0-9]n[0-9] matches disks only, not partitions (nvme*n*p*)
      ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
      
      # Set I/O scheduler to 'mq-deadline' for SATA SSDs
      ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
    '';
  });
}

# ==============================================================================
# About Gaming Optimizations
# ==============================================================================
#
# This module provides comprehensive gaming optimizations using Chaotic-Nyx:
#
# 1. Gamescope (gamescope_git):
#    - SteamOS session compositor
#    - Better frame pacing and VRR support
#    - FSR upscaling built-in
#    - HDR support
#
# 2. MangoHud (mangohud_git):
#    - Real-time performance overlay
#    - FPS, frame times, temperatures
#    - CPU/GPU load monitoring
#    - Customizable display
#
# 3. Proton-CachyOS:
#    - Optimized Wine/Proton builds
#    - Better game compatibility
#    - 5-10% performance improvement
#    - Architecture-specific builds (v2/v3/v4)
#
# 4. LatencyFleX:
#    - Reduces input latency in games
#    - Vulkan layer
#    - Particularly beneficial for competitive games
#
# 5. System Tweaks:
#    - GameMode integration
#    - Increased file descriptor limits (esync/fsync)
#    - Optimized I/O schedulers
#    - AMD GPU optimizations
#
# Usage:
#   myModules.chaotic.gaming = {
#     enable = true;
#     cpuMicroarch = "v3";  # or "v4" for latest CPUs
#   };
#
# For Ryzen 9 9950X3D, use cpuMicroarch = "v4" for best performance!
#
# ==============================================================================

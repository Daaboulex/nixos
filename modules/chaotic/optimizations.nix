{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.chaotic.optimizations = {
    enable = lib.mkEnableOption "Chaotic-Nyx package optimizations";
    
    enableMesaGit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable bleeding-edge Mesa Git drivers (WARNING: May break NVIDIA Optimus)";
    };
    
    enableSchedExt = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable sched-ext CPU schedulers (requires CachyOS kernel 6.12+)";
    };
    
    schedExtScheduler = lib.mkOption {
      type = lib.types.enum [
        # ===== Gaming/Latency Optimized =====
        "scx_lavd"      # RECOMMENDED for gaming - Latency-Aware Virtual Deadline
        "scx_bpfland"   # Interactive workloads, cache-aware (good for gaming)
        "scx_flash"     # Ultra-low latency scheduler
        
        # ===== General Purpose =====
        "scx_rusty"     # Multi-domain hybrid scheduler (slight gaming boost)
        "scx_rustland"  # Rust-based general purpose
        "scx_simple"    # Minimal scheduler for debugging
        
        # ===== Specialized =====
        "scx_layered"   # Hierarchical scheduling for mixed workloads
        "scx_nest"      # NUMA-aware nested domains
        "scx_p2dq"      # Priority-2-Domain queue
        "scx_pair"      # Paired CPU scheduling
        "scx_cosmos"    # Cluster-optimized scheduling
        "scx_central"   # Centralized scheduling
        "scx_flatcg"    # Flat cgroup scheduler
        "scx_mitosis"   # Cell division inspired
        "scx_sdt"       # Soft deadline scheduler
        "scx_wd40"      # Watchdog scheduler
        
        # ===== Experimental/Testing =====
        "scx_prev"      # Previous task affinity
        "scx_qmap"      # Queue map scheduler
        "scx_rlfifo"    # Rate-limited FIFO
        "scx_tickless"  # Tickless operation
        "scx_userland"  # Userland scheduling
        "scx_chaos"     # Chaos engineering/testing
      ];
      default = "scx_lavd";  # Best for gaming based on research
      description = ''
        Sched_ext scheduler to use. Recommendations for gaming/desktop:
        
        For Ryzen 9950X3D (Gaming Focus):
          - scx_lavd: BEST - Latency-Aware Virtual Deadline, minimizes stuttering
          - scx_bpfland: Great alternative, cache-layout aware
          
        For General Desktop:
          - scx_rusty: Good all-rounder with slight gaming benefits
          - scx_rustland: Conservative general-purpose scheduler
          
        All available schedulers are enumerated above.
      '';
    };
    
    # NOTE: useGitVersion option removed - scx_git is deprecated and now an alias of scx
  };

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf config.myModules.chaotic.optimizations.enable {
    # ==========================================================================
    # Mesa Git - Bleeding-Edge Graphics Drivers
    # ==========================================================================
    # WARNING: This will break NVIDIA's libgbm - don't use with NVIDIA Optimus!
    # Provides the absolute latest Mesa drivers with performance improvements
    # and newest feature support (OpenGL, Vulkan, VA-API, etc.)
    chaotic.mesa-git = {
      enable = config.myModules.chaotic.optimizations.enableMesaGit;
      fallbackSpecialisation = false;  # Create fallback boot option with stable Mesa
    };

    # ==========================================================================
    # Graphics Package Optimizations
    # ==========================================================================
    # Replace standard graphics packages with bleeding-edge versions from
    # the Chaotic-Nyx repository. These packages are often more recent than
    # nixpkgs-unstable and may include performance optimizations.
    hardware.graphics.extraPackages = lib.mkOverride 40 (with pkgs; [
      # VDPAU to VA-API translation layer
      libvdpau-va-gl

      # Direct Rendering Manager (DRM) library - Git version for latest features
      libdrm_git

      # Mesa 3D graphics library
      # Note: Will use mesa_git if chaotic.mesa-git.enable is true
      # mesa

      # Comprehensive Vulkan support - Latest versions from Chaotic
      vulkanPackages_latest.vulkan-loader
      vulkanPackages_latest.vulkan-tools
      vulkanPackages_latest.vulkan-validation-layers
      vulkanPackages_latest.vulkan-extension-layer
      vulkanPackages_latest.vulkan-utility-libraries
      vulkanPackages_latest.spirv-tools
      vulkanPackages_latest.spirv-headers
      vulkanPackages_latest.spirv-cross
      #vulkanPackages_latest.glslang
    ] ++ lib.optionals (config.myModules.hardware.graphics.intel.enable or false) [
      # Intel-specific drivers (only if Intel graphics are enabled)
      intel-media-driver    # VAAPI driver for Intel GPUs (Broadwell+)
      intel-vaapi-driver    # Legacy VAAPI driver for older Intel GPUs
    ]);

    # ==========================================================================
    # Wayland Optimizations
    # ==========================================================================
    # Use bleeding-edge Wayland packages for latest protocol support and
    # performance improvements. Particularly beneficial for KDE Plasma on Wayland.
    environment.systemPackages = with pkgs; [
      # Wayland Core - Git versions for latest protocol support
      wayland_git             # Latest Wayland compositor library from git
      wayland-protocols_git   # Latest Wayland protocol definitions from git
      wayland-scanner_git     # Latest Wayland scanner for protocol generation
      
      # Wayland Compositing Libraries
      wlroots_git            # Modular Wayland compositor library (used by Sway, etc.)
      
      # SDL - Simple DirectMedia Layer (for games and multimedia)
      #sdl_git                # Latest SDL with Wayland improvements
      #TODO Build broke

      # System Libraries - Git versions for performance
      nss_git                # Network Security Services (used by browsers)
      #libportal_git          # Flatpak portal library
      
      # eBPF Tools - For advanced system monitoring and performance tuning
      #libbpf_git             # Library for loading eBPF programs
      #bpftools_full          # Complete eBPF debugging and analysis tools
      #TODO Build broke
    ];

    # ==========================================================================
    # Sched-ext CPU Schedulers (Optional)
    # ==========================================================================
    # Modern CPU schedulers that can provide better performance for specific
    # workloads. Requires CachyOS kernel 6.12+ or linux_latest.
    # Available schedulers:
    #   - scx_rustland: Rust-based, general purpose (default)
    #   - scx_rusty: Rust-based, optimized for gaming
    #   - scx_lavd: Latency-aware scheduler
    #   - scx_bpfland: BPF-based scheduler
    services.scx = lib.mkIf config.myModules.chaotic.optimizations.enableSchedExt {
      enable = true;
      scheduler = config.myModules.chaotic.optimizations.schedExtScheduler;
      package = pkgs.scx.full;
    };

    # Automatically add sched_ext kernel parameter when scheduler is enabled
    boot.kernelParams = lib.mkIf config.myModules.chaotic.optimizations.enableSchedExt [
      "sched_ext"
    ];

    # ==========================================================================
    # System-wide Performance Tweaks
    # ==========================================================================
    # Additional environment variables and settings for optimal performance
    environment.sessionVariables = {
      # Force Wayland for supported applications
      NIXOS_OZONE_WL = "1";
      
      # Use Wayland-native SDL backend
      SDL_VIDEODRIVER = "wayland";
      
      # Vulkan ICD selection (will use latest from Chaotic)
      VK_DRIVER_FILES = lib.mkDefault "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json";
    };
  };
}

# ==============================================================================
# About Chaotic-Nyx Optimizations
# ==============================================================================
#
# Chaotic-Nyx is a Nix package repository that provides:
# - Bleeding-edge packages (often newer than nixpkgs-unstable)
# - Optimized builds with aggressive compiler flags
# - Packages from various projects including CachyOS
#
# Repository: https://github.com/chaotic-cx/nyx
#
# This module uses Chaotic-Nyx packages for maximum performance:
#
# 1. Graphics Stack:
#    - mesa_git: Bleeding-edge Mesa drivers
#    - libdrm_git: Latest Direct Rendering Manager
#    - vulkanPackages_latest.*: Comprehensive Vulkan support
#
# 2. Wayland Ecosystem:
#    - wayland_git, wayland-protocols_git: Latest Wayland support
#    - wlroots_git: Modern compositor library
#
# 3. System Libraries:
#    - sdl_git: Latest SDL for gaming/multimedia
#    - nss_git: Browser security and performance
#    - libportal_git: Flatpak integration
#
# 4. Performance Tools:
#    - libbpf_git, bpftools_full: eBPF for system monitoring
#    - scx schedulers: Modern CPU scheduling algorithms
#
# Note: The Chaotic-Nyx overlay must be configured in flake.nix for these
# packages to be available. Without the overlay, standard nixpkgs versions
# will be used instead.
#
# WARNING: mesa-git will break NVIDIA Optimus setups! Disable enableMesaGit
# if you use NVIDIA Optimus (hybrid graphics).
#
# ==============================================================================

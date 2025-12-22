{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.kernel = {
    enable = lib.mkEnableOption "Custom kernel selection and configuration";

    variant = lib.mkOption {
      type = lib.types.enum [
        "cachyos"           # Standard CachyOS kernel
        "cachyos-lto"       # CachyOS with Link Time Optimization
        "cachyos-gcc"       # CachyOS built with GCC
        "cachyos-hardened"  # Hardened CachyOS kernel
        "cachyos-lts"       # Long Term Support CachyOS
        "cachyos-rc"        # Release Candidate CachyOS
        "cachyos-server"    # Server-optimized CachyOS
        "xanmod"            # Xanmod kernel
        "default"           # Standard NixOS kernel
      ];
      default = "cachyos-lto";
      description = "Kernel variant to use";
    };

    laptopSafe = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use laptop-safe settings (disables hugepages and aggressive optimizations)";
    };

    extraParams = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional kernel parameters to append";
      example = [ "intel_pstate=active" "quiet" ];
    };

    preferLocalBuild = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Force local kernel compilation instead of using binary cache";
    };

    mArch = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "GENERIC_V2" "GENERIC_V3" "GENERIC_V4" "ZEN4" ]);
      default = null;
      description = "CPU microarchitecture optimization level. Use GENERIC_V4 for Zen 5 (9950X3D).";
      example = "GENERIC_V4";
    };
  };

  # Legacy options for backwards compatibility
  options.myModules.kernel.cachyos = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Legacy option - use myModules.kernel.enable instead";
    };

    laptopSafe = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Legacy option - use myModules.kernel.laptopSafe instead";
    };
  };

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = let
    # Determine if kernel module is enabled (new or legacy option)
    enabled = config.myModules.kernel.enable || config.myModules.kernel.cachyos.enable;

    # Get variant selection
    variant = config.myModules.kernel.variant;

    # Determine laptop-safe mode (prefer new option, fall back to legacy)
    laptopSafe = if config.myModules.kernel.enable
                 then config.myModules.kernel.laptopSafe
                 else config.myModules.kernel.cachyos.laptopSafe;

    # Base kernel parameters for all configurations
    baseParams = [
      "quiet"                           # Reduce boot messages
      "transparent_hugepage=madvise"    # Only use hugepages when requested
      "net.core.default_qdisc=fq_codel" # Fair Queue CoDel for network
    ];

    # Performance parameters (only for desktop/server, not laptops)
    perfParams = lib.optionals (!laptopSafe) [
      "default_hugepagesz=2M"           # Default hugepage size
      "hugepagesz=2M"                   # Hugepage size
      "hugepages=2048"                  # Reserve 4GB for hugepages
      "vm.swappiness=10"                # Reduce swapping
      "vm.vfs_cache_pressure=50"        # Reduce cache pressure
      "vm.dirty_ratio=15"               # Dirty page ratio
      "vm.dirty_background_ratio=5"     # Background dirty page ratio
      "mitigations=off"                 # Disable CPU vulnerability mitigations (performance)
      "preempt=voluntary"               # Voluntary preemption
      "clocksource=tsc"                 # Use TSC clocksource
    ];

    # Select kernel package based on variant
    baseKernel =
      if variant == "cachyos-lto" then pkgs.linuxPackages_cachyos-lto
      else if variant == "cachyos" then pkgs.linuxPackages_cachyos
      else if variant == "cachyos-gcc" then pkgs.linuxPackages_cachyos-gcc
      else if variant == "cachyos-hardened" then pkgs.linuxPackages_cachyos-hardened
      else if variant == "cachyos-lts" then pkgs.linuxPackages_cachyos-lts
      else if variant == "cachyos-rc" then pkgs.linuxPackages_cachyos-rc
      else if variant == "cachyos-server" then pkgs.linuxPackages_cachyos-server
      else if variant == "xanmod" then pkgs.linuxKernel.packages.linux_xanmod_latest
      else pkgs.linuxPackages;

    # Apply mArch override if specified (for CachyOS kernels only)
    mArch = config.myModules.kernel.mArch;
    chosenKernel =
      if mArch != null && lib.hasPrefix "cachyos" variant
      then baseKernel.cachyOverride { inherit mArch; }
      else baseKernel;

    # Override kernel to prefer local build if requested
    finalKernelPkgs =
      if config.myModules.kernel.preferLocalBuild
      then chosenKernel.extend (self: super: {
        kernel = super.kernel.overrideAttrs (_: {
          allowSubstitutes = false;
          preferLocalBuild = true;
        });
      })
      else chosenKernel;

  in lib.mkIf enabled {
    # Set the kernel package
    boot.kernelPackages = finalKernelPkgs;

    # Combine all kernel parameters
    boot.kernelParams = lib.unique (baseParams ++ perfParams ++ config.myModules.kernel.extraParams);

    # Disable power-profiles-daemon (conflicts with custom kernel settings)
    services.power-profiles-daemon.enable = false;
  };
}
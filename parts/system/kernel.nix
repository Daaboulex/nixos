{ inputs, ... }: {
  flake.nixosModules.system-kernel = { config, lib, pkgs, ... }: {
    options.myModules.kernel = {
      enable = lib.mkEnableOption "Custom kernel configuration";
      variant = lib.mkOption { type = lib.types.enum [ "cachyos" "cachyos-lto" "cachyos-sched-ext" "zen" "xanmod" "default" ]; default = "default"; description = "Kernel variant to use (cachyos, zen, xanmod, or NixOS default)"; };
      laptopSafe = lib.mkEnableOption "Laptop-safe configuration (cachyos)";
      preferLocalBuild = lib.mkEnableOption "Prefer local build (no cache)";
      mArch = lib.mkOption { type = lib.types.str; default = "x86-64-v3"; description = "Microarchitecture for CachyOS kernel (x86-64-v3, x86-64-v4, ZEN4, ZEN5, etc.)"; };
      extraParams = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; description = "Extra kernel parameters"; };
      
      cachyos = {
        cpusched = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "CPU scheduler (e.g. bmq, bore, eevdf)"; };
        bbr3 = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = null; description = "Enable BBR3 TCP congestion control"; };
        hzTicks = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Timer frequency (e.g. 1000, 500, 300)"; };
        kcfi = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = null; description = "Enable KCFI (Kernel Control Flow Integrity)"; };
        performanceGovernor = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = null; description = "Default to performance governor"; };
        tickrate = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Tickless behavior (e.g. full, idle)"; };
        preemptType = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Preemption model (e.g. full, voluntary)"; };
        ccHarder = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = null; description = "Enable -O3 optimizations"; };
        hugepage = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Transparent Hugepage behavior (e.g. always, madvise)"; };
      };
    };

    config = lib.mkIf config.myModules.kernel.enable {
      boot.kernelPackages =
        let
          v = config.myModules.kernel.variant;
          arch = config.myModules.kernel.mArch;
          cachyosArch = 
            if arch == "ZEN4" || arch == "ZEN5" || arch == "zen4" then "-zen4"
            else if arch == "x86-64-v4" || arch == "v4" then "-x86_64-v4"
            else if arch == "x86-64-v3" || arch == "v3" then "-x86_64-v3"
            else if arch == "x86-64-v2" || arch == "v2" then "-x86_64-v2"
            else "";
          cachyosSuffix = (if v == "cachyos-lto" || v == "cachyos-sched-ext" then "-lto" else "") + cachyosArch;
          
          # Only pass defined inputs to the override
          cachyosOverrides = lib.filterAttrs (n: v: v != null) {
            inherit (config.myModules.kernel.cachyos) cpusched bbr3 hzTicks kcfi performanceGovernor tickrate preemptType ccHarder hugepage;
          };
          
          baseCachyKernel = pkgs.cachyosKernels."linux-cachyos-latest${cachyosSuffix}";
          customCachyKernel = if cachyosOverrides == {} then baseCachyKernel else baseCachyKernel.override cachyosOverrides;
          
          # If we customized the kernel, we need to wrap it; otherwise we can use the pre-built packages.
          customCachyKernelPackages = if cachyosOverrides == {} then pkgs.cachyosKernels."linuxPackages-cachyos-latest${cachyosSuffix}" else pkgs.linuxPackagesFor customCachyKernel;
        in
          if v == "cachyos" || v == "cachyos-lto" || v == "cachyos-sched-ext" then customCachyKernelPackages
          else if v == "zen" then pkgs.linuxPackages_zen
          else if v == "xanmod" then pkgs.linuxPackages_xanmod
          else pkgs.linuxPackages;

      # Apply extra parameters
      boot.kernelParams = config.myModules.kernel.extraParams ++ 
        lib.optionals (config.myModules.kernel.variant != "default") [
          # Common CachyOS params if needed
        ];
    };
  };
}

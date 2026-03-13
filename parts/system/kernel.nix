{ inputs, ... }:
{
  flake.nixosModules.system-kernel =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.system.kernel;
    in
    {
      _class = "nixos";
      options.myModules.system.kernel = {
        enable = lib.mkEnableOption "Custom kernel configuration";
        variant = lib.mkOption {
          type = lib.types.enum [
            "cachyos"
            "cachyos-lto"
            "cachyos-sched-ext"
            "zen"
            "xanmod"
            "default"
          ];
          default = "default";
          description = "Kernel variant to use (cachyos, zen, xanmod, or NixOS default)";
        };
        channel = lib.mkOption {
          type = lib.types.enum [
            "latest"
            "lts"
            "rc"
          ];
          default = "latest";
          description = "CachyOS kernel channel: latest (stable bleeding-edge), lts (long-term support), rc (release candidate)";
        };
        mArch = lib.mkOption {
          type = lib.types.str;
          default = "x86-64-v3";
          description = "Microarchitecture for CachyOS kernel (x86-64-v3, x86-64-v4, ZEN4, ZEN5, etc.)";
        };
        extraParams = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra kernel parameters";
        };

        cachyos = {
          cpusched = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "CPU scheduler (e.g. bmq, bore, eevdf)";
          };
          bbr3 = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "BBR3 TCP congestion control";
          };
          hzTicks = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Timer frequency (e.g. 1000, 500, 300)";
          };
          kcfi = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "KCFI (Kernel Control Flow Integrity)";
          };
          performanceGovernor = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Default to performance governor";
          };
          tickrate = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Tickless behavior (e.g. full, idle)";
          };
          preemptType = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Preemption model (e.g. full, voluntary)";
          };
          ccHarder = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "-O3 optimizations";
          };
          hugepage = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Transparent Hugepage behavior (e.g. always, madvise)";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        boot.kernelPackages =
          let
            v = cfg.variant;
            ch = cfg.channel;
            arch = cfg.mArch;
            cachyosArch =
              if arch == "ZEN4" || arch == "ZEN5" || arch == "zen4" then
                "-zen4"
              else if arch == "x86-64-v4" || arch == "v4" then
                "-x86_64-v4"
              else if arch == "x86-64-v3" || arch == "v3" then
                "-x86_64-v3"
              else if arch == "x86-64-v2" || arch == "v2" then
                "-x86_64-v2"
              else
                "";

            # rc channel has no microarch variants or LTO
            cachyosSuffix =
              if ch == "rc" then
                ""
              else
                (if v == "cachyos-lto" || v == "cachyos-sched-ext" then "-lto" else "") + cachyosArch;
            cachyosChannel =
              if ch == "rc" then
                "rc"
              else if ch == "lts" then
                "lts"
              else
                "latest";

            # Only pass defined inputs to the override
            cachyosOverrides = lib.filterAttrs (_: v: v != null) {
              inherit (cfg.cachyos)
                cpusched
                bbr3
                hzTicks
                kcfi
                performanceGovernor
                tickrate
                preemptType
                ccHarder
                hugepage
                ;
            };

            baseCachyKernel = pkgs.cachyosKernels."linux-cachyos-${cachyosChannel}${cachyosSuffix}";
            customCachyKernel =
              if cachyosOverrides == { } then baseCachyKernel else baseCachyKernel.override cachyosOverrides;

            # If we customized the kernel, we need to wrap it; otherwise use pre-built packages
            customCachyKernelPackages =
              if cachyosOverrides == { } then
                pkgs.cachyosKernels."linuxPackages-cachyos-${cachyosChannel}${cachyosSuffix}"
              else
                pkgs.linuxPackagesFor customCachyKernel;
          in
          if v == "cachyos" || v == "cachyos-lto" || v == "cachyos-sched-ext" then
            customCachyKernelPackages
          else if v == "zen" then
            pkgs.linuxPackages_zen
          else if v == "xanmod" then
            pkgs.linuxPackages_xanmod
          else
            pkgs.linuxPackages;

        boot.kernelParams = cfg.extraParams;
      };
    };
}

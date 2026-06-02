# kernel — custom kernel variant selector (cachyos, zen, stock).
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.boot.kernel;

      # ─── Stock nixpkgs variants ────────────────────────────────────────────
      # Keep this table near the top so adding a new variant = one line edit.
      # Every entry must point at a package set that has .kernel + .extend.
      stockVariants = {
        "default" = pkgs.linuxPackages; # current NixOS default (LTS-ish per channel)
        "latest" = pkgs.linuxPackages_latest; # mainline stable, newest minor
        "hardened" = pkgs.linuxPackages_hardened; # KSPP-recommended hardening
        "zen" = pkgs.linuxPackages_zen; # Zen Kernel — desktop/interactive tuning
        "lqx" = pkgs.linuxPackages_lqx; # Liquorix — low-latency desktop focus
        "rt" = pkgs.linuxPackages_rt; # PREEMPT_RT on LTS
        "rt-latest" = pkgs.linuxPackages_rt_latest; # PREEMPT_RT on mainline
      };
    in
    {
      _class = "nixos";

      options.myModules.boot.kernel = {
        enable = lib.mkEnableOption "custom kernel variant selection";

        variant = lib.mkOption {
          type = lib.types.enum (
            (lib.attrNames stockVariants)
            ++ [
              # CachyOS family — composable with `channel` and `cachyos.*` below.
              "cachyos"
              "cachyos-lto"
              "cachyos-sched-ext"
              "cachyos-bore"
              "cachyos-lts"
              "cachyos-server"
              "cachyos-rt"
              "cachyos-hardened"
            ]
          );
          default = "default";
          description = ''
            Kernel variant. Stock nixpkgs variants are resolved from a lookup
            table; CachyOS variants go through the CachyOS override path and
            pick up `channel` + `mArch` + `cachyos.*` sub-options.

            **Ivy Bridge (x86-64-v2) compatibility**: setting `mArch =
            "x86-64-v2"` routes to the v2-compiled variant. v2 attrs ship
            from `inputs.nix-cachyos-kernel.overlays.pinned` directly
            (restored upstream after a brief drop in PR #50). v2 kernels
            still build locally — no upstream binary cache.
            `cachyos-rc` has no per-arch variants (channel=rc
            short-circuits the suffix).
          '';
        };

        channel = lib.mkOption {
          type = lib.types.enum [
            "latest"
            "lts"
            "rc"
          ];
          default = "latest";
          description = ''
            CachyOS channel selector (ignored for non-CachyOS variants).
            `rc` disables LTO + per-arch variants.
          '';
        };

        mArch = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "x86-64-v2"
              "x86-64-v3"
              "x86-64-v4"
              "v2"
              "v3"
              "v4"
              "ZEN4"
              "ZEN5"
              "zen4"
              "none"
            ]
          );
          default = null;
          defaultText = lib.literalExpression "null (derived from myModules.host.tier)";
          description = ''
            Microarchitecture for CachyOS kernel variants. Ignored for stock
            variants. Use `none` to get the CachyOS generic build.

            When left as `null`, defaults to the `x86-64-v{N}` generic build
            matching `myModules.host.tier` (v2 → x86-64-v2, etc.). Hosts
            that want a uarch-specific compile target (e.g. `ZEN5` on Zen 5
            hardware) set this explicitly.
          '';
        };

        extraParams = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra kernel cmdline parameters to append.";
          example = lib.literalExpression ''[ "mitigations=auto" "quiet" ]'';
        };

        # ─── CachyOS build-time knobs ──────────────────────────────────────
        # All nullable — only overrides the CachyOS default when set.
        cachyos = {
          cpusched = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "bmq"
                "bore"
                "eevdf"
                "hardened"
                "rt"
                "rt-bore"
                "sched-ext"
              ]
            );
            default = null;
            description = "CPU scheduler flavor the CachyOS kernel is built with.";
          };
          bbr3 = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Enable BBR3 TCP congestion control.";
          };
          hzTicks = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "100"
                "250"
                "300"
                "500"
                "750"
                "1000"
              ]
            );
            default = null;
            description = "Timer frequency (HZ).";
          };
          kcfi = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Kernel Control Flow Integrity.";
          };
          performanceGovernor = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Default to the `performance` cpufreq governor at boot.";
          };
          tickrate = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "periodic"
                "idle"
                "full"
              ]
            );
            default = null;
            description = "Tickless mode.";
          };
          preemptType = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "none"
                "voluntary"
                "server"
                "lazy"
                "full"
                "rt"
              ]
            );
            default = null;
            description = "Kernel preemption model.";
          };
          ccHarder = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Extra -O3 / compiler aggressiveness.";
          };
          hugepage = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "always"
                "madvise"
                "never"
              ]
            );
            default = null;
            description = "Transparent Hugepage default.";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        boot.kernelPackages =
          let
            v = cfg.variant;
            ch = cfg.channel;
            # mArch defaults derive from host.tier when unset.
            tierToMArch = {
              v2 = "x86-64-v2";
              v3 = "x86-64-v3";
              v4 = "x86-64-v4";
            };
            arch = if cfg.mArch != null then cfg.mArch else tierToMArch.${config.myModules.host.tier};

            # Map mArch → CachyOS suffix.
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

            # Map CachyOS variant → CachyOS flavor name for nixpkgs attr.
            # (Not all combinations are valid; invalid ones fail eval with a
            # clear attr-not-found — that's the intended error path.)
            cachyosFlavorSuffix =
              if v == "cachyos-lto" || v == "cachyos-sched-ext" then
                "-lto"
              else if v == "cachyos-bore" then
                "-bore"
              else if v == "cachyos-rt" then
                "-rt"
              else if v == "cachyos-hardened" then
                "-hardened"
              else if v == "cachyos-server" then
                "-server"
              else
                "";

            # rc channel has no LTO/arch variants.
            cachyosSuffix = if ch == "rc" then "" else cachyosFlavorSuffix + cachyosArch;

            cachyosChannel =
              if ch == "rc" then
                "rc"
              else if ch == "lts" || v == "cachyos-lts" then
                "lts"
              else
                "latest";

            # Only pass defined overrides.
            cachyosOverrides = lib.filterAttrs (_: val: val != null) {
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

            customCachyKernelPackages =
              if cachyosOverrides == { } then
                pkgs.cachyosKernels."linuxPackages-cachyos-${cachyosChannel}${cachyosSuffix}"
              else
                pkgs.linuxPackagesFor customCachyKernel;

            # VFIO-stealth postPatch hook — applied last so it layers on top of
            # whatever variant was chosen.
            stealthPostPatch = config.myModules.vfio.stealth._kernelPostPatch or "";
            applyStealthPatch =
              krnl:
              if stealthPostPatch != "" then
                krnl.overrideAttrs (old: {
                  postPatch = (old.postPatch or "") + stealthPostPatch;
                })
              else
                krnl;
            applyStealthPatchPkgs =
              krnlPkgs:
              if stealthPostPatch != "" then
                pkgs.linuxPackagesFor (applyStealthPatch krnlPkgs.kernel)
              else
                krnlPkgs;

            isCachy = lib.hasPrefix "cachyos" v;
            chosen = if isCachy then customCachyKernelPackages else stockVariants.${v};
          in
          applyStealthPatchPkgs chosen;

        boot.kernelParams = cfg.extraParams;
      };
    };
in
{
  flake.modules.nixos.boot-kernel = mod;

}

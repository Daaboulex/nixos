{ inputs, ... }:
{
  flake.nixosModules.cachyos-settings =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.cachyos.settings;

      # All upstream sub-option names (passed through to cachyos.settings.*)
      upstreamToggles = [
        "zram"
        "ioSchedulers"
        "audio"
        "storage"
        "thp"
        "systemd"
        "timesyncd"
        "networkManager"
        "ntsync"
        "debuginfod"
        "coredump"
        "nvidia"
        "amdgpuGcnCompat"
      ];

      # GPU-specific toggles default to false; all others default to true
      gpuToggles = [
        "nvidia"
        "amdgpuGcnCompat"
      ];

      mkSubEnable =
        name:
        let
          isGpu = builtins.elem name gpuToggles;
        in
        lib.mkEnableOption "CachyOS ${name}" // lib.optionalAttrs (!isGpu) { default = true; };
    in
    {
      _class = "nixos";
      # ==================================================================
      # Options — myModules wrapper + extraPerformance (not upstream)
      # ==================================================================
      options.myModules.cachyos.settings = {
        enable = lib.mkEnableOption "CachyOS system optimizations (upstream-matched settings)";

        # Generate sub-option enables that mirror cachyos.settings.*
      }
      // lib.genAttrs upstreamToggles (name: {
        enable = mkSubEnable name;
      })
      // {
        # --- Extra performance sysctls (NOT from CachyOS upstream) ---
        extraPerformance.enable =
          lib.mkEnableOption "Extra performance sysctls: BBR, cake, tcp_fastopen, buffer sizes, max_map_count, compaction, sched_autogroup"
          // {
            default = true;
          };
      };

      # ==================================================================
      # Config — pass-through to cachyos.settings.* + local extraPerformance
      # ==================================================================
      config = lib.mkIf cfg.enable (
        lib.mkMerge [

          # Pass through all upstream toggles to cachyos.settings.*
          {
            cachyos.settings = {
              enable = true;
            }
            // lib.genAttrs upstreamToggles (name: {
              inherit (cfg.${name}) enable;
            });
          }

          # ================================================================
          # Extra Performance Sysctls — NOT from CachyOS upstream
          # Desktop/gaming-oriented tuning beyond what CachyOS-Settings ships
          # ================================================================
          (lib.mkIf cfg.extraPerformance.enable {
            boot.kernel.sysctl = {
              # TCP: BBR congestion control
              "net.ipv4.tcp_congestion_control" = "bbr";
              # TCP: CAKE qdisc for better latency and fairness
              "net.core.default_qdisc" = "cake";
              # TCP: Enable TCP Fast Open for client + server
              "net.ipv4.tcp_fastopen" = 3;
              # TCP: Increase buffer sizes for high-bandwidth connections
              "net.core.rmem_max" = 16777216;
              "net.core.wmem_max" = 16777216;

              # Gaming/Proton: required by many Steam/Proton games
              "vm.max_map_count" = 2147483642;
              # Desktop: disable proactive memory compaction (reduces latency spikes on 64GB+)
              "vm.compaction_proactiveness" = 0;
              # Desktop: disable CFS autogroups (let sched_ext/bore handle scheduling)
              "kernel.sched_autogroup_enabled" = 0;
            };
          })
        ]
      );
    };
}

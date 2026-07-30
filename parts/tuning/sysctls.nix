# sysctls — extra performance sysctls (BBR, CAKE, tcp_fastopen, buffer sizes, max_map_count).
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
      cfg = config.myModules.tuning.sysctls;
    in
    {
      _class = "nixos";
      options.myModules.tuning.sysctls = {
        enable =
          lib.mkEnableOption "Extra performance sysctls: BBR, CAKE, tcp_fastopen, buffer sizes, max_map_count"
          // {
            default = true;
          };
      };

      config = lib.mkIf cfg.enable {
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

          # TCP: maintain throughput on reconnect (don't restart slow-start after idle)
          "net.ipv4.tcp_slow_start_after_idle" = 0;

          # Gaming/Proton: required by many Steam/Proton games
          "vm.max_map_count" = 2147483642;
          # Desktop: disable proactive memory compaction (reduces latency spikes on 64GB+)
          "vm.compaction_proactiveness" = 0;
          # Desktop: disable CFS autogroups (let sched_ext/bore handle scheduling)
          "kernel.sched_autogroup_enabled" = 0;
          # Desktop: reduce page lock contention tail latency (default 5)
          "vm.page_lock_unfairness" = 1;

          # TCP: faster dead-connection detection (default 7200s = 2 hours)
          "net.ipv4.tcp_keepalive_time" = 60;
          "net.ipv4.tcp_keepalive_intvl" = 10;
          "net.ipv4.tcp_keepalive_probes" = 6;
        };
      };
    };
in
{
  flake.modules.nixos.tuning-sysctls = mod;

}

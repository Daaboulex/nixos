{ config, pkgs, lib, osConfig ? {}, ... }:

let
  hasAmdGpu = (osConfig.myModules.hardware.graphics.amd.enable or false);
in {
  # ============================================================================
  # btop++ — System & GPU monitor
  # ============================================================================
  # NOTE: enable is set per-host in home/hosts/<hostname>.nix
  # AMD GPU detection requires rocm-smi (btop dlopen's librocm_smi64.so)
  programs.btop.package = lib.mkDefault (pkgs.btop.override {
    rocmSupport = hasAmdGpu;
  });
  programs.btop.settings = {
      # -- Appearance --
      color_theme = "tokyo-night";
      theme_background = false;
      vim_keys = true;
      rounded_corners = true;
      graph_symbol = "block";         # Block chars — crisp solid bars
      graph_symbol_cpu = "block";
      graph_symbol_gpu = "block";
      graph_symbol_mem = "block";
      graph_symbol_net = "tty";       # Simpler graph for network

      # -- Layout --
      # Override shown_boxes per-host to add GPUs (e.g. "cpu gpu0 gpu1 mem proc")
      # Press 'p' to cycle presets
      shown_boxes = lib.mkDefault "cpu mem proc";
      presets = lib.mkDefault "cpu:0:default,mem:0:default,proc:0:default cpu:0:default,mem:0:default,net:0:default,proc:0:default";
      show_battery = false;           # Desktop — no battery

      # -- Refresh --
      update_ms = 1000;

      # -- CPU --
      cpu_single_graph = true;        # Single combined graph (cleaner for many threads)
      cpu_bottom = false;
      show_uptime = true;
      check_temp = true;
      show_coretemp = true;           # Per-core temps
      temp_scale = "celsius";
      show_cpu_freq = true;
      cpu_graph_upper = "total";      # Upper graph: total CPU
      cpu_graph_lower = "user";       # Lower graph: user-space only
      clock_format = "%X";

      # -- GPU --
      show_gpu_info = "On";           # Show GPU stats in CPU box header
      gpu_mirror_graph = true;        # Mirror GPU graph like CPU

      # -- Memory / Disks --
      mem_graphs = true;
      show_swap = true;
      swap_disk = true;
      show_disks = true;
      show_io_stat = true;
      io_mode = false;
      only_physical = true;           # Hide loop/snap mounts
      use_fstab = true;               # Only show fstab disks
      disks_filter = "exclude=/boot /tmp";  # Hide small/noisy mounts

      # -- Network (visible in preset 2) --
      net_download = 1000;            # Scale: 1 Gbps
      net_upload = 1000;
      net_auto = true;
      net_sync = false;

      # -- Process List --
      proc_sorting = "cpu";
      proc_reversed = true;           # Highest CPU at top
      proc_per_core = false;          # Total CPU% (not per-core)
      proc_tree = false;              # Flat list for clean CPU sorting
      proc_colors = true;
      proc_gradient = false;          # No gradient
      proc_aggregate = true;          # Aggregate child CPU into parent
      proc_filter_kernel = true;      # Hide kernel threads (kworker, migration, rcu_*)
      proc_mem_bytes = true;          # Show actual bytes, not %
      background_update = true;
  };
}

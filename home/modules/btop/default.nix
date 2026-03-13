{
  config,
  pkgs,
  lib,
  osConfig ? { },
  ...
}:

let
  hasAmdGpu = osConfig.myModules.hardware.gpu.amd.enable or false;
  btopBase = pkgs.btop.override {
    rocmSupport = hasAmdGpu;
  };
  # btop uses dlopen("librocm_smi64.so") at runtime for AMD GPU monitoring.
  # RUNPATH only covers linked deps, not dlopen — wrap with LD_LIBRARY_PATH.
  btopWrapped =
    if hasAmdGpu then
      pkgs.symlinkJoin {
        name = "btop-rocm-wrapped";
        paths = [ btopBase ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/btop \
            --prefix LD_LIBRARY_PATH : "${pkgs.rocmPackages.rocm-smi}/lib"
        '';
      }
    else
      btopBase;
in
{
  # ============================================================================
  # btop++ — System & GPU monitor
  # ============================================================================
  # NOTE: enable is set per-host in home/hosts/<hostname>.nix
  # AMD GPU detection requires rocm-smi (btop dlopen's librocm_smi64.so)
  programs.btop.package = lib.mkDefault btopWrapped;
  programs.btop.settings = {
    # -- Appearance --
    color_theme = lib.mkDefault "tokyo-night";
    theme_background = lib.mkDefault false;
    vim_keys = lib.mkDefault true;
    rounded_corners = lib.mkDefault true;
    graph_symbol = lib.mkDefault "block"; # Block chars — crisp solid bars
    graph_symbol_cpu = lib.mkDefault "block";
    graph_symbol_gpu = lib.mkDefault "block";
    graph_symbol_mem = lib.mkDefault "block";
    graph_symbol_net = lib.mkDefault "tty"; # Simpler graph for network

    # -- Layout --
    # Override shown_boxes per-host to add GPUs (e.g. "cpu gpu0 gpu1 mem proc")
    # Press 'p' to cycle presets
    selected_preset = lib.mkDefault 0; # Always launch on preset 0
    shown_boxes = lib.mkDefault "cpu mem proc";
    presets = lib.mkDefault "cpu:0:default,mem:0:default,proc:0:default cpu:0:default,mem:0:default,net:0:default,proc:0:default";
    show_battery = lib.mkDefault false; # Override per-host for laptops

    # -- Refresh --
    update_ms = lib.mkDefault 1000;

    # -- CPU --
    cpu_single_graph = lib.mkDefault true; # Single combined graph (cleaner for many threads)
    cpu_bottom = lib.mkDefault false;
    show_uptime = lib.mkDefault true;
    check_temp = lib.mkDefault true;
    show_coretemp = lib.mkDefault true; # Per-core temps
    temp_scale = lib.mkDefault "celsius";
    show_cpu_freq = lib.mkDefault true;
    cpu_graph_upper = lib.mkDefault "total"; # Upper graph: total CPU
    cpu_graph_lower = lib.mkDefault "user"; # Lower graph: user-space only
    clock_format = lib.mkDefault "%X";

    # -- GPU --
    show_gpu_info = lib.mkDefault "On"; # Show GPU stats in CPU box header
    gpu_mirror_graph = lib.mkDefault true; # Mirror GPU graph like CPU

    # -- Memory / Disks --
    mem_graphs = lib.mkDefault true;
    show_swap = lib.mkDefault true;
    swap_disk = lib.mkDefault true;
    show_disks = lib.mkDefault true;
    show_io_stat = lib.mkDefault true;
    io_mode = lib.mkDefault false;
    only_physical = lib.mkDefault true; # Hide loop/snap mounts
    use_fstab = lib.mkDefault true; # Only show fstab disks
    disks_filter = lib.mkDefault "exclude=/boot /tmp"; # Hide small/noisy mounts

    # -- Network (visible in preset 2) --
    net_download = lib.mkDefault 1000; # Scale: 1 Gbps
    net_upload = lib.mkDefault 1000;
    net_auto = lib.mkDefault true;
    net_sync = lib.mkDefault false;

    # -- Process List --
    proc_sorting = lib.mkDefault "cpu";
    proc_reversed = lib.mkDefault true; # Highest CPU at top
    proc_per_core = lib.mkDefault true; # Show real CPU% (not divided by core count, matches htop)
    proc_tree = lib.mkDefault false; # Flat list for clean CPU sorting
    proc_colors = lib.mkDefault true;
    proc_gradient = lib.mkDefault false; # No gradient
    proc_aggregate = lib.mkDefault true; # Aggregate child CPU into parent
    proc_filter_kernel = lib.mkDefault true; # Hide kernel threads (kworker, migration, rcu_*)
    proc_mem_bytes = lib.mkDefault true; # Show actual bytes, not %
    background_update = lib.mkDefault true;
  };
}

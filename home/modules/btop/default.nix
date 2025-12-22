{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # btop - Modern system monitor
  # ============================================================================
  # NOTE: enable is set per-host in home/hosts/<hostname>.nix
  programs.btop.settings = {
      color_theme = "tokyo-night";
      theme_background = false;
      vim_keys = true;
      rounded_corners = true;
      graph_symbol = "braille";
      shown_boxes = "cpu mem net proc";
      update_ms = 1000;
      proc_sorting = "cpu lazy";
      proc_tree = true;
      proc_colors = true;
      proc_gradient = false;
      cpu_single_graph = false;
      show_uptime = true;
      check_temp = true;
      show_coretemp = true;
      temp_scale = "celsius";
      show_cpu_freq = true;
      clock_format = "%X";
      background_update = true;
      mem_graphs = true;
      show_swap = true;
      swap_disk = true;
      show_disks = true;
      show_io_stat = true;
      io_mode = false;
      net_download = 100;
      net_upload = 100;
      net_auto = true;
      net_sync = false;
  };
}

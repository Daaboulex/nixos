{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # htop - Interactive process viewer
  # ============================================================================
  # NOTE: enable is set per-host in home/hosts/<hostname>.nix
  programs.htop.settings = {
      show_program_path = false;
      hide_kernel_threads = true;
      hide_userland_threads = true;
      highlight_base_name = true;
      highlight_megabytes = true;
      highlight_threads = true;
      tree_view = true;
      header_margin = true;
      detailed_cpu_time = false;
      cpu_count_from_one = true;
      show_cpu_usage = true;
      show_cpu_frequency = true;
      show_cpu_temperature = true;
      degree_fahrenheit = false;
      update_process_names = true;
      account_guest_in_cpu_meter = false;
      enable_mouse = true;
      delay = 15;
      color_scheme = 0;
  };
}

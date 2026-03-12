{
  config,
  pkgs,
  lib,
  ...
}:

{
  # ============================================================================
  # htop - Interactive process viewer
  # ============================================================================
  # NOTE: enable is set per-host in home/hosts/<hostname>.nix
  programs.htop.settings = {
    show_program_path = lib.mkDefault false;
    hide_kernel_threads = lib.mkDefault true;
    hide_userland_threads = lib.mkDefault true;
    highlight_base_name = lib.mkDefault true;
    highlight_megabytes = lib.mkDefault true;
    highlight_threads = lib.mkDefault true;
    tree_view = lib.mkDefault true;
    header_margin = lib.mkDefault true;
    detailed_cpu_time = lib.mkDefault false;
    cpu_count_from_one = lib.mkDefault true;
    show_cpu_usage = lib.mkDefault true;
    show_cpu_frequency = lib.mkDefault true;
    show_cpu_temperature = lib.mkDefault true;
    degree_fahrenheit = lib.mkDefault false;
    update_process_names = lib.mkDefault true;
    account_guest_in_cpu_meter = lib.mkDefault false;
    enable_mouse = lib.mkDefault true;
    delay = lib.mkDefault 15;
    color_scheme = lib.mkDefault 0;
  };
}

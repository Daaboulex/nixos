{ inputs, ... }: {
  flake.nixosModules.system-chaotic = { config, lib, pkgs, ... }: {
    options.myModules.chaotic.optimizations = {
      enable = lib.mkEnableOption "Chaotic-Nyx package optimizations";
      
      enableMesaGit = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable bleeding-edge Mesa Git drivers";
      };
      
      enableSchedExt = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable sched-ext CPU schedulers";
      };
      
      schedExtScheduler = lib.mkOption {
        type = lib.types.enum [
          "scx_lavd" "scx_bpfland" "scx_flash" "scx_rusty" "scx_rustland" "scx_simple"
          "scx_layered" "scx_nest" "scx_p2dq" "scx_pair" "scx_cosmos" "scx_central"
          "scx_flatcg" "scx_mitosis" "scx_sdt" "scx_wd40" "scx_prev" "scx_qmap"
          "scx_rlfifo" "scx_tickless" "scx_userland" "scx_chaos"
        ];
        default = "scx_lavd";
        description = "Sched_ext scheduler to use";
      };
    };

    config = lib.mkIf config.myModules.chaotic.optimizations.enable {
      chaotic.mesa-git = {
        enable = config.myModules.chaotic.optimizations.enableMesaGit;
        fallbackSpecialisation = false;
      };

      hardware.graphics.extraPackages = lib.mkOverride 40 (with pkgs; [
        libvdpau-va-gl libdrm_git
        vulkanPackages_latest.vulkan-loader
        vulkanPackages_latest.vulkan-tools
        vulkanPackages_latest.vulkan-validation-layers
        vulkanPackages_latest.vulkan-extension-layer
        vulkanPackages_latest.vulkan-utility-libraries
        vulkanPackages_latest.spirv-tools
        vulkanPackages_latest.spirv-headers
        vulkanPackages_latest.spirv-cross
      ] ++ lib.optionals (config.myModules.hardware.graphics.intel.enable or false) [
        intel-media-driver intel-vaapi-driver
      ]);

      environment.systemPackages = with pkgs; [
        wayland_git wayland-protocols_git wayland-scanner_git wlroots_git
        nss_git
      ];

      services.scx = lib.mkIf config.myModules.chaotic.optimizations.enableSchedExt {
        enable = true;
        scheduler = config.myModules.chaotic.optimizations.schedExtScheduler;
        package = pkgs.scx.full;
      };

      boot.kernelParams = lib.mkIf config.myModules.chaotic.optimizations.enableSchedExt [ "sched_ext" ];

      environment.sessionVariables = {
        NIXOS_OZONE_WL = "1";
        SDL_VIDEODRIVER = "wayland";
        VK_DRIVER_FILES = lib.mkDefault "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json";
      };
    };
  };
}

# radv — RADV Vulkan driver session variables (RADV_PERFTEST, device selection).
{
  config,
  lib,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.radv;
in
{
  options.myModules.home.radv = {
    enable = lib.mkEnableOption "RADV Vulkan driver session variables";
    experimental = lib.mkOption {
      type = lib.types.str;
      default = "nggc,transfer_queue";
      description = "RADV_PERFTEST flags for AMD Vulkan driver (comma-separated). gpl removed (default since Mesa 23.1), transfer_queue added (Mesa 26.0 async DMA)";
    };
    vulkanDeviceName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "GPU name substring for DXVK/VKD3D device filtering (forces dGPU for translated DX9-12 games).";
    };
  };
  config = lib.mkIf cfg.enable (
    myLib.mkSessionVars (
      {
        AMD_VULKAN_ICD = lib.mkDefault "RADV";
        RADV_PERFTEST = cfg.experimental;
        MESA_SHADER_CACHE_MAX_SIZE = lib.mkDefault "4G"; # Prevent shader cache eviction with many games (default 1G)
      }
      // lib.optionalAttrs (cfg.vulkanDeviceName != null) {
        DXVK_FILTER_DEVICE_NAME = cfg.vulkanDeviceName;
        VKD3D_FILTER_DEVICE_NAME = cfg.vulkanDeviceName;
      }
    )
  );
}

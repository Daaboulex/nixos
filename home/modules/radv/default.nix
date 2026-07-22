# radv — RADV Vulkan driver session variables (RADV_EXPERIMENTAL, device selection).
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
      default = "transfer_queue";
      description = "RADV_EXPERIMENTAL flags for AMD Vulkan driver (comma-separated). transfer_queue = Mesa 26 async DMA transfer-only queue. nggc/gpl are default-on and need no flag; transfer_queue moved here from RADV_PERFTEST in Mesa 26.";
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
        RADV_EXPERIMENTAL = cfg.experimental;
        MESA_SHADER_CACHE_MAX_SIZE = lib.mkDefault "4G"; # Prevent shader cache eviction with many games (default 1G)
      }
      // lib.optionalAttrs (cfg.vulkanDeviceName != null) {
        DXVK_FILTER_DEVICE_NAME = cfg.vulkanDeviceName;
        VKD3D_FILTER_DEVICE_NAME = cfg.vulkanDeviceName;
      }
    )
  );
}

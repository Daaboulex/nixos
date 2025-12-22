{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.hardware.graphics.intel.enable =
    lib.mkEnableOption "Intel Graphics (i915) configuration";

  # Intel i915 kernel parameter options
  options.hardware.intel.kernelParams = {
    enablePsr = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Panel Self Refresh (PSR) - may cause flickering on some displays";
    };

    enableFbc = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Frame Buffer Compression (FBC) - reduces power consumption";
    };

    enableDc = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Display C-states (DC) - deeper power saving states";
    };
  };

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf config.myModules.hardware.graphics.intel.enable {
    boot.kernelParams = lib.mkMerge [
      (lib.mkIf config.hardware.intel.kernelParams.enablePsr [ "i915.enable_psr=1" ])
      (lib.mkIf config.hardware.intel.kernelParams.enableFbc [ "i915.enable_fbc=1" ])
      (lib.mkIf config.hardware.intel.kernelParams.enableDc [ "i915.enable_dc=2" ])
    ];
  };
}
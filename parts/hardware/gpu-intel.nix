{ inputs, ... }: {
  flake.nixosModules.hardware-gpu-intel = { config, lib, pkgs, ... }: {
    options.myModules.hardware.graphics.intel.enable =
      lib.mkEnableOption "Intel Graphics (i915) configuration";

    options.myModules.hardware.graphics.intel = {
      kernelParams = {
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
    };

    config = lib.mkIf config.myModules.hardware.graphics.intel.enable {
      boot.kernelParams = lib.mkMerge [
        (lib.mkIf config.myModules.hardware.graphics.intel.kernelParams.enablePsr [ "i915.enable_psr=1" ])
        (lib.mkIf config.myModules.hardware.graphics.intel.kernelParams.enableFbc [ "i915.enable_fbc=1" ])
        (lib.mkIf config.myModules.hardware.graphics.intel.kernelParams.enableDc [ "i915.enable_dc=2" ])
      ];
    };
  };
}

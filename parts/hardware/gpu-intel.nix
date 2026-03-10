{ inputs, ... }: {
  flake.nixosModules.hardware-gpu-intel = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.hardware.graphics.intel;
    in {
      _class = "nixos";
      options.myModules.hardware.graphics.intel = {
        enable = lib.mkEnableOption "Intel Graphics (i915) configuration";

        kernelParams = {
          enablePsr = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Panel Self Refresh (PSR) — may cause flickering on some displays";
          };

          enableFbc = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Frame Buffer Compression (FBC) — reduces power consumption";
          };

          enableDc = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Display C-states (DC) — deeper power saving states";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        boot.kernelParams = lib.mkMerge [
          (lib.mkIf cfg.kernelParams.enablePsr [ "i915.enable_psr=1" ])
          (lib.mkIf cfg.kernelParams.enableFbc [ "i915.enable_fbc=1" ])
          (lib.mkIf cfg.kernelParams.enableDc [ "i915.enable_dc=2" ])
        ];
      };
    };
}

{ inputs, ... }:
{
  flake.nixosModules.hardware-gpu-intel =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.hardware.gpu.intel;
    in
    {
      _class = "nixos";
      options.myModules.hardware.gpu.intel = {
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

        openCL = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "OpenCL support via RustiCL (Mesa) iris driver";
        };
      };

      config = lib.mkIf cfg.enable {
        # Contribute iris to the shared RustiCL driver list in graphics.nix
        myModules.hardware.graphics.openCL.rusticlDrivers = lib.mkIf cfg.openCL [ "iris" ];

        boot.kernelParams = lib.mkMerge [
          (lib.mkIf cfg.kernelParams.enablePsr [ "i915.enable_psr=1" ])
          (lib.mkIf cfg.kernelParams.enableFbc [ "i915.enable_fbc=1" ])
          (lib.mkIf cfg.kernelParams.enableDc [ "i915.enable_dc=2" ])
        ];
      };
    };
}

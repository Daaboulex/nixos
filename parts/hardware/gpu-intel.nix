# gpu-intel — Intel Graphics (i915) with Mesa and VA-API/QSV acceleration.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.hardware.gpuIntel;
    in
    {
      _class = "nixos";
      options.myModules.hardware.gpuIntel = {
        enable = lib.mkEnableOption "Intel Graphics (i915) configuration";

        # Tri-state: null = leave the param off the cmdline (kernel default);
        # true = enable (i915.enable_X=1, or =2 for DC); false = explicitly DISABLE
        # (i915.enable_X=0). The null-able bool lets a host express "force off" --
        # a plain bool could only ever ADD the =1 form, so explicit-disable used to
        # be hand-written as a raw kernelParam string.
        kernelParams = {
          enablePsr = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Panel Self Refresh (PSR). null=kernel default, true==1, false==0. May flicker on some displays.";
          };

          enableFbc = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Frame Buffer Compression (FBC). null=kernel default, true==1, false==0. Lowers power.";
          };

          enableDc = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Display C-states (DC). null=kernel default, true==2, false==0. Deeper power saving.";
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
        myModules.hardware.graphics.openCL.rusticlDrivers = lib.mkIf cfg.openCL [ "iris" ]; # foreign-ok: graphics.nix rusticlDrivers accumulator

        # Emit i915.enable_X only when the tri-state is non-null: true -> the param's
        # "on" value (=1, or =2 for DC), false -> =0 (explicit disable).
        boot.kernelParams =
          let
            p = cfg.kernelParams;
            mk =
              name: onVal: v:
              lib.optionals (v != null) [ "i915.enable_${name}=${if v then onVal else "0"}" ];
          in
          mk "psr" "1" p.enablePsr ++ mk "fbc" "1" p.enableFbc ++ mk "dc" "2" p.enableDc;
      };
    };
in
{
  flake.modules.nixos.hardware-gpu-intel = mod;

}

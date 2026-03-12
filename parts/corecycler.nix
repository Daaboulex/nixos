{ inputs, withSystem, ... }:
{
  flake.nixosModules.corecycler =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.corecycler;
      perSystem = withSystem pkgs.stdenv.hostPlatform.system ({ inputs', ... }: inputs');
    in
    {
      _class = "nixos";

      options.myModules.corecycler = {
        enable = lib.mkEnableOption "Linux CoreCycler per-core CPU stability tester and PBO Curve Optimizer tuner";
        ryzenSmu = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to load the ryzen_smu kernel module for Curve Optimizer read/write via SMU";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [
          perSystem.linux-corecycler.packages.default
        ];

        # ryzen_smu kernel module for Curve Optimizer SMU access (Zen 2–5)
        boot.kernelModules = lib.mkIf cfg.ryzenSmu [ "ryzen_smu" ];
      };
    };
}

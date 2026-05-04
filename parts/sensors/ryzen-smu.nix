# ryzen-smu — AMD ryzen_smu kernel module (Curve Optimizer, PBO, boost override).
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
      cfg = config.myModules.sensors.ryzenSmu;
      ryzenSmuPkg = pkgs.callPackage ./drivers/ryzen-smu.nix {
        inherit (config.boot.kernelPackages) kernel;
      };
    in
    {
      _class = "nixos";
      options.myModules.sensors.ryzenSmu = {
        enable = lib.mkEnableOption "AMD ryzen_smu kernel module (Curve Optimizer, PBO, boost override)";
      };
      config = lib.mkIf cfg.enable {
        boot.kernelModules = [ "ryzen_smu" ];
        boot.extraModulePackages = [ ryzenSmuPkg ];
      };
    };
in
{
  flake.modules.nixos.sensors-ryzen-smu = mod;

}

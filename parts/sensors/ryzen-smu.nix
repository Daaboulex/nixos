# ryzen-smu — AMD ryzen_smu kernel module (Curve Optimizer, PBO, boost override).
{ inputs, ... }:
(import ../../lib/mkSimpleNixosModule.nix { lib = inputs.nixpkgs.lib; }) {
  scope = "sensors";
  name = "ryzen-smu";
  description = "AMD ryzen_smu kernel module (Curve Optimizer, PBO, boost override)";
  config =
    { config, pkgs, ... }:
    {
      boot.kernelModules = [ "ryzen_smu" ];
      boot.extraModulePackages = [
        (pkgs.callPackage ./drivers/ryzen-smu.nix { inherit (config.boot.kernelPackages) kernel; })
      ];
    };
}

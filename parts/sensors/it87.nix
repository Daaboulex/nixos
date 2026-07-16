# it87 — ITE IT87xx Super I/O sensors (out-of-tree, 38+ chip models).
{ inputs, ... }:
(import ../../lib/mkSimpleNixosModule.nix { lib = inputs.nixpkgs.lib; }) {
  scope = "sensors";
  name = "it87";
  description = "ITE IT87xx Super I/O sensors (out-of-tree, 38+ chip models)";
  config =
    { config, pkgs, ... }:
    {
      boot.kernelModules = [ "it87" ];
      boot.extraModulePackages = [
        (pkgs.callPackage ./drivers/it87.nix { inherit (config.boot.kernelPackages) kernel; })
      ];
    };
}

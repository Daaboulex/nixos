# zenpower — Zenpower5 AMD CPU sensors (replaces k10temp — Zen 1 through Zen 5).
{ inputs, ... }:
(import ../../lib/mkSimpleNixosModule.nix { lib = inputs.nixpkgs.lib; }) {
  scope = "sensors";
  name = "zenpower";
  description = "Zenpower5 AMD CPU sensors (replaces k10temp — Zen 1 through Zen 5)";
  config =
    { config, pkgs, ... }:
    {
      boot.kernelModules = [ "zenpower" ];
      boot.extraModulePackages = [
        (pkgs.callPackage ./drivers/zenpower.nix { inherit (config.boot.kernelPackages) kernel; })
      ];
      boot.blacklistedKernelModules = [ "k10temp" ];
    };
}

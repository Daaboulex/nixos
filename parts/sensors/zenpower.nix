# zenpower — Zenpower5 AMD CPU sensors (replaces k10temp — Zen 1 through Zen 5).
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
      cfg = config.myModules.sensors.zenpower;
      zenpowerPkg = pkgs.callPackage ./drivers/zenpower.nix {
        inherit (config.boot.kernelPackages) kernel;
      };
    in
    {
      _class = "nixos";
      options.myModules.sensors.zenpower = {
        enable = lib.mkEnableOption "Zenpower5 AMD CPU sensors (replaces k10temp — Zen 1 through Zen 5)";
      };
      config = lib.mkIf cfg.enable {
        boot.kernelModules = [ "zenpower" ];
        boot.extraModulePackages = [ zenpowerPkg ];
        boot.blacklistedKernelModules = [ "k10temp" ];
      };
    };
in
{
  flake.modules.nixos.sensors-zenpower = mod;

}

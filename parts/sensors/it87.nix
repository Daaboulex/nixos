# it87 — ITE IT87xx Super I/O sensors (out-of-tree, 38+ chip models).
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
      cfg = config.myModules.sensors.it87;
      it87Pkg = pkgs.callPackage ./drivers/it87.nix {
        inherit (config.boot.kernelPackages) kernel;
      };
    in
    {
      _class = "nixos";
      options.myModules.sensors.it87 = {
        enable = lib.mkEnableOption "ITE IT87xx Super I/O sensors (out-of-tree, 38+ chip models)";
      };
      config = lib.mkIf cfg.enable {
        boot.kernelModules = [ "it87" ];
        boot.extraModulePackages = [ it87Pkg ];
      };
    };
in
{
  flake.modules.nixos.sensors-it87 = mod;

}

# module-guards — eval-time assertions + warnings against mis-layered / conflicting
# kernel modules (load+blacklist conflicts, mutually-exclusive drivers, an
# uncleanly-released GPU under passthrough, late-only modules wrongly in the initrd).
# The logic + registry live in lib/kernelModuleGuards.nix so they scale and stay
# testable; this module just wires them into the host. Enabled by default so every
# host that imports it is guarded.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      myLib,
      ...
    }:
    let
      cfg = config.myModules.boot.moduleGuards;
    in
    {
      _class = "nixos";
      options.myModules.boot.moduleGuards = {
        enable = lib.mkEnableOption "kernel-module layering guards (assertions + warnings)" // {
          default = true;
        };
      };
      config = lib.mkIf cfg.enable (myLib.kernelModuleGuards { inherit config; });
    };
in
{
  flake.modules.nixos.boot-module-guards = mod;

}

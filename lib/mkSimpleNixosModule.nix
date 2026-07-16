# mkSimpleNixosModule — factory for trivial NixOS wrapper modules; the
# system-side analog of mkSimplePackage.
#
# Many parts/ modules are the identical scaffold: one enable option at
# options.myModules.<scope>.<leaf>, a config body under `mkIf cfg.enable`,
# exported as flake.modules.nixos.<scope>-<name>. This collapses each file
# to a single call while keeping option paths, export names, and the
# per-file layout the gates expect. The option leaf is the camelCase of
# `name` (ryzen-smu -> ryzenSmu), mirroring check-placement's mapping, and
# the generated module carries `_class = "nixos"` like every hand-written
# wrapper.
#
# Consumer files are flake-parts modules. They import the factory directly
# with inputs.nixpkgs.lib — NOT via inputs.self.lib, which at flake-parts
# composition time is a self-reference and infinitely recurses:
#
#   # parts/sensors/msr.nix
#   { inputs, ... }:
#   (import ../../lib/mkSimpleNixosModule.nix { lib = inputs.nixpkgs.lib; }) {
#     scope = "sensors";
#     name = "msr";
#     description = "x86 MSR access (APERF/MPERF, RAPL energy counters)";
#     config = _: { boot.kernelModules = [ "msr" ]; };
#   }
#
# `config` is a function of the module args, so a body can use pkgs or
# config.boot.kernelPackages (out-of-tree driver builds).
{ lib }:
{
  scope,
  name,
  description,
  config,
}:
let
  cfgBody = config;
  segments = lib.splitString "-" name;
  capitalize =
    s: lib.toUpper (builtins.substring 0 1 s) + builtins.substring 1 (builtins.stringLength s) s;
  leaf = builtins.head segments + lib.concatMapStrings capitalize (builtins.tail segments);
in
{
  # Explicit formal args: the module system inspects functionArgs to decide
  # what to inject, so a bare `args:` lambda would never receive pkgs.
  flake.modules.nixos."${scope}-${name}" =
    {
      config,
      pkgs,
      ...
    }@args:
    let
      cfg = config.myModules.${scope}.${leaf};
    in
    {
      _class = "nixos";
      options.myModules.${scope}.${leaf} = {
        enable = lib.mkEnableOption description;
      };
      config = lib.mkIf cfg.enable (cfgBody args);
    };
}

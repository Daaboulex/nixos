# mkSimplePackage — factory for trivial HM wrapper modules.
#
# A large number of HM modules are identical 15-line boilerplate: one
# enable option, and a `mkIf cfg.enable { home.packages = [ pkgs.X ]; }`.
# This helper collapses them to a single line in the module file while
# preserving the per-file layout the auto-importer in
# home/modules/default.nix expects.
#
# Consumer files are a wrapper lambda that receives `myLib` (via
# specialArgs) plus the standard module args, applies the factory, and
# forwards the full arg set to the generated module:
#
#   # home/modules/dust/default.nix
#   {
#     config,
#     lib,
#     pkgs,
#     myLib,
#     ...
#   }@args:
#   (myLib.mkSimplePackage {
#     name = "dust";
#     description = "intuitive disk usage viewer";
#   }) args
#
# Usage — package name differs (e.g. attr `moonlight-qt` vs module `moonlight`):
#   (myLib.mkSimplePackage {
#     name = "moonlight";
#     package = p: p.moonlight-qt;
#     description = "Moonlight game streaming client";
#   }) args
#
# Usage — nested attr path (e.g. kdePackages):
#   (myLib.mkSimplePackage {
#     name = "partitionmanager";
#     package = p: p.kdePackages.partitionmanager;
#     description = "KDE Partition Manager";
#   }) args
#
# Usage — multiple packages:
#   (myLib.mkSimplePackage {
#     name = "android";
#     packages = p: [ p.android-tools p.scrcpy ];
#     description = "Android development tools";
#   }) args
#
# The generated module is functionally identical to writing the boilerplate
# by hand. Option path, enable default (false), and package list shape all
# match hand-written wrappers, so host config files see no API difference.

{
  name,
  description,
  package ? null,
  packages ? null,
}:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.home.${name};
  pkgList =
    if packages != null then
      packages pkgs
    else if package != null then
      [ (package pkgs) ]
    else
      [ pkgs.${name} ];
in
{
  options.myModules.home.${name}.enable = lib.mkEnableOption description;

  config = lib.mkIf cfg.enable {
    home.packages = pkgList;
  };
}

{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "nix-tree";
  description = "nix-tree — explore Nix store dependency trees";
})
  args

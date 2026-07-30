{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "nix-prefetch-git";
  description = "nix-prefetch-git";
})
  args

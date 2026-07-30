{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "comma";
  description = "comma — run uninstalled programs via nix-index";
})
  args

{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "nvd";
  description = "nvd — Nix version diff between system generations";
})
  args

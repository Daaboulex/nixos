{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "pciutils";
  description = "pciutils (lspci)";
})
  args

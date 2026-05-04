{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "protonplus";
  description = "ProtonPlus for managing Proton versions";
})
  args

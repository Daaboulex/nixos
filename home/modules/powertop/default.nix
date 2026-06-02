{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "powertop";
  description = "powertop power analysis";
})
  args

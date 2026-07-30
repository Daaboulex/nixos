{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "smartmontools";
  description = "smartmontools disk health (smartctl)";
})
  args

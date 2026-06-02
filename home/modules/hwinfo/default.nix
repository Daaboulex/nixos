{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "hwinfo";
  description = "hwinfo hardware information";
})
  args

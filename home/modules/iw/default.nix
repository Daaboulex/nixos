{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "iw";
  description = "iw wireless configuration";
})
  args

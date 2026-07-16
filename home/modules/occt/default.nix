{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "occt";
  description = "OCCT stability test/benchmark";
})
  args

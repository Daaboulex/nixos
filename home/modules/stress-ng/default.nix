{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "stress-ng";
  description = "stress-ng stress testing";
})
  args

{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "pkg-config";
  description = "pkg-config build helper";
})
  args

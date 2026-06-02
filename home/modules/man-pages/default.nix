{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "man-pages";
  description = "Linux man pages";
})
  args

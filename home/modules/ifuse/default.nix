{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "ifuse";
  description = "ifuse (FUSE mount for iOS devices)";
})
  args

{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "libimobiledevice";
  description = "libimobiledevice (iOS device communication)";
})
  args

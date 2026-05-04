{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "usbutils";
  description = "usbutils (lsusb)";
})
  args

{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "ns-usbloader";
  description = "Nintendo Switch USB loader and NSP installer";
})
  args

{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "bluez-tools";
  description = "bluez-tools Bluetooth CLI";
})
  args

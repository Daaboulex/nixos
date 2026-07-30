{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "brightnessctl";
  description = "brightnessctl display brightness control";
})
  args

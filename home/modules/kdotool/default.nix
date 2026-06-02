{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "kdotool";
  description = "kdotool (xdotool for KDE Wayland)";
})
  args

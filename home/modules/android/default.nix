{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "android";
  package = p: p.android-tools;
  description = "Android device connectivity (adb, fastboot)";
})
  args

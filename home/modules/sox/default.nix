{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "sox";
  description = "SoX audio toolkit for voice recording";
})
  args

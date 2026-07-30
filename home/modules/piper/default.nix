{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "piper";
  description = "Piper mouse configuration tool";
})
  args

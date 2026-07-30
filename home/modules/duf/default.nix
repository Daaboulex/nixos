{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "duf";
  description = "duf modern disk free utility";
})
  args

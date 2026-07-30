{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "lshw";
  description = "lshw hardware lister";
})
  args

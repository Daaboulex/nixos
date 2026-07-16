{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "sd";
  description = "sd intuitive find-and-replace (sed alternative)";
})
  args

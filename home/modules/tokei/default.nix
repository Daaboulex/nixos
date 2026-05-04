{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "tokei";
  description = "tokei fast code statistics";
})
  args

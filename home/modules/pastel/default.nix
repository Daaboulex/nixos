{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "pastel";
  description = "pastel color manipulation CLI";
})
  args

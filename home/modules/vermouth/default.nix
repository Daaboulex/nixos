{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "vermouth";
  description = "Vermouth game and app launcher";
})
  args

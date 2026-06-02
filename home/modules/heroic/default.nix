{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "heroic";
  description = "Heroic Games Launcher";
})
  args

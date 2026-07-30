{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "gparted";
  description = "GParted graphical partition editor";
})
  args

{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "mangojuice";
  description = "MangoJuice GUI for MangoHud configuration";
})
  args

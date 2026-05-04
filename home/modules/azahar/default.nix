{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "azahar";
  description = "Azahar 3DS emulator";
})
  args

# eden — Eden Switch emulator.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "eden";
  description = "Eden Switch emulator";
})
  args

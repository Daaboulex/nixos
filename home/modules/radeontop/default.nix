{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "radeontop";
  description = "radeontop AMD GPU utilization monitor";
})
  args

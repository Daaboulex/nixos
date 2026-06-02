{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "lact";
  description = "LACT AMD GPU overclocking/monitoring GUI";
})
  args

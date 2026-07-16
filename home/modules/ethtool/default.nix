{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "ethtool";
  description = "ethtool Ethernet diagnostics";
})
  args

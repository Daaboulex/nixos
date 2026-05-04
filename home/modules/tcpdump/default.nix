{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "tcpdump";
  description = "tcpdump — network packet analyzer";
})
  args

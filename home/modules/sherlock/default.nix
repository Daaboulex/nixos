{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "sherlock";
  description = "Sherlock username OSINT tool";
})
  args

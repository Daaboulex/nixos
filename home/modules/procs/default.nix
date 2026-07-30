{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "procs";
  description = "procs modern ps replacement";
})
  args

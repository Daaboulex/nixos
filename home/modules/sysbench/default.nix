{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "sysbench";
  description = "sysbench system benchmark";
})
  args

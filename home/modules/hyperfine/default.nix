{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "hyperfine";
  description = "hyperfine command-line benchmarking";
})
  args

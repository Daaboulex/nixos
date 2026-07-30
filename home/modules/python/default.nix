{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "python";
  package = p: p.python3;
  description = "Python environment";
})
  args

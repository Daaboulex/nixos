{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "fd";
  description = "fd file finder (used by Telescope, fzf)";
})
  args

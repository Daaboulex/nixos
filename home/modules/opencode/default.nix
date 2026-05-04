{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "opencode";
  description = "OpenCode AI terminal agent";
})
  args

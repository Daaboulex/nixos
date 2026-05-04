{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "claude-code";
  description = "Claude Code AI assistant";
})
  args

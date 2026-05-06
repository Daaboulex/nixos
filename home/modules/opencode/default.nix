{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "opencode";
  description = "OpenCode AI coding agent (sst/opencode)";
  package = p: p.llm-agents.opencode;
})
  args

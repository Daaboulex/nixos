{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "crush";
  description = "Crush AI coding agent (charmbracelet)";
  package = p: p.llm-agents.crush;
})
  args

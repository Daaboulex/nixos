{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "pi";
  package = p: p.llm-agents.pi;
  description = "Pi AI agent CLI (earendil-works)";
})
  args

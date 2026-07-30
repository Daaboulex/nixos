{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "antigravity";
  description = "Google Antigravity agentic IDE (agy CLI)";
  package = p: p.llm-agents.antigravity-cli;
})
  args

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
  package = p: p.llm-agents.claude-code;
})
  args

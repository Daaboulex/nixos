{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "codex-cli";
  description = "Codex CLI AI assistant";
  package = p: p.llm-agents.codex;
})
  args

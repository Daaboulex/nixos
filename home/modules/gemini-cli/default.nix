{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "gemini-cli";
  description = "Gemini CLI AI assistant";
  package = p: p.llm-agents.gemini-cli;
})
  args

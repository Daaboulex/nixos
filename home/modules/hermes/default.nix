{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "hermes";
  description = "Hermes self-improving AI agent orchestrator (Nous Research)";
  package = p: p.llm-agents.hermes-agent;
})
  args

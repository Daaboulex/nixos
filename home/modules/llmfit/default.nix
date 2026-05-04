{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "llmfit";
  description = "llmfit LLM context window calculator";
})
  args

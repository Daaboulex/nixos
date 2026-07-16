{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "models";
  package = p: p.models-cli;
  description = "Models CLI — TUI for AI models, benchmarks, and coding agents";
})
  args

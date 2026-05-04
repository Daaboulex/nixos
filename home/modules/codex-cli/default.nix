{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "codex-cli";
  package = p: p.codex;
  description = "Codex CLI AI assistant";
})
  args

{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "nix-output-monitor";
  description = "nix-output-monitor (nom) — pretty nix build output";
})
  args

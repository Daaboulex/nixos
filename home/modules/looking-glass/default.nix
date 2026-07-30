{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "looking-glass";
  package = p: p.looking-glass-client;
  description = "Looking Glass client for KVMFR frame relay";
})
  args

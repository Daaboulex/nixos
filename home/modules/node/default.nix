{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "node";
  package = p: p.nodejs;
  description = "Node.js environment";
})
  args

{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "saleae";
  package = p: p.saleae-logic-2;
  description = "Saleae Logic analyzer";
})
  args

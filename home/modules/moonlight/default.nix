{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "moonlight";
  package = p: p.moonlight-qt;
  description = "Moonlight game streaming client";
})
  args

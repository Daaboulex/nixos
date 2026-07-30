{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "anydesk";
  description = "AnyDesk remote desktop client";
})
  args

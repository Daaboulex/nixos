{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "samba";
  description = "Samba SMB client and server tools";
})
  args

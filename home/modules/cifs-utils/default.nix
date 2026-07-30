{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "cifs-utils";
  description = "CIFS/SMB filesystem utilities";
})
  args

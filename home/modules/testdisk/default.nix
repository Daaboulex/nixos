{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "testdisk";
  description = "TestDisk/PhotoRec data recovery tools";
})
  args

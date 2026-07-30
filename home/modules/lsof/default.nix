{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "lsof";
  description = "lsof open files lister";
})
  args

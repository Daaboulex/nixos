{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "dust";
  description = "dust intuitive disk usage viewer";
})
  args

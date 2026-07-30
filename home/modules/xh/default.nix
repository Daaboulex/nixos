{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "xh";
  description = "xh friendly HTTP client (curl alternative)";
})
  args

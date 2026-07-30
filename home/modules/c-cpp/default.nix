{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "c-cpp";
  package = p: p.clang-tools;
  description = "C/C++ tools (clang-tools)";
})
  args

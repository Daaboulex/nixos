{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "memtest-vulkan";
  package = p: p.memtest_vulkan;
  description = "memtest_vulkan GPU memory test";
})
  args

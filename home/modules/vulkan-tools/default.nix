{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "vulkan-tools";
  packages =
    p: with p; [
      vulkan-tools
      mesa-demos
    ];
  description = "Vulkan and Mesa graphics diagnostic tools";
})
  args

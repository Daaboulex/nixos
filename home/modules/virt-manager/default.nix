{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "virt-manager";
  packages =
    p: with p; [
      virt-manager
      virt-viewer
    ];
  description = "virt-manager and virt-viewer VM management GUIs";
})
  args

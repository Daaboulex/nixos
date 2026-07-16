{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "prismlauncher";
  description = "Prism Launcher for Minecraft";
})
  args

{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "ryubing";
  description = "Ryubing Switch emulator";
})
  args

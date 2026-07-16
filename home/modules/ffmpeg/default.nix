{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "ffmpeg";
  description = "ffmpeg multimedia framework";
})
  args

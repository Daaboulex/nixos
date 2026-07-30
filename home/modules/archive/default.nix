{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "archive";
  packages =
    p: with p; [
      unzip
      zip
      p7zip
      unrar
    ];
  description = "archive tools (zip, unzip, p7zip, unrar)";
})
  args

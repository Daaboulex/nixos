{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "chafa";
  description = "chafa terminal image viewer";
})
  args

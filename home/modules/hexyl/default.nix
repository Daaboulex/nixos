# hexyl — modern hex viewer (colored, byte-category aware; better xxd/hexdump).
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "hexyl";
  description = "hexyl hex viewer";
})
  args

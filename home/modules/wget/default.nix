# wget — HTTP download client with user .wgetrc configuration.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkDotfileModule {
  name = "wget";
  description = "wget HTTP client";
  file = ".wgetrc";
})
  args

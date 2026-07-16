# curl — HTTP client with user .curlrc configuration.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkDotfileModule {
  name = "curl";
  description = "curl HTTP client";
  file = ".curlrc";
  exampleLines = "`--compressed`, `--location`, `--max-time 30`.";
})
  args

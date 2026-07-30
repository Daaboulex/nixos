# fastfetch looks good with defaults on a Breeze Dark terminal.
# programs.fastfetch.settings replaces the entire config (breaks modules),
# and CLI color wrappers don't render well with the small logo.
# Keep it simple — just the package.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "fastfetch";
  description = "fastfetch system info display";
})
  args

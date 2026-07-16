{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "powershell";
  description = "PowerShell (pwsh)";
})
  args

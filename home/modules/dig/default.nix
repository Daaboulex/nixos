{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "dig";
  packages = p: [ p.bind.dnsutils ];
  description = "dig, nslookup, host — classic DNS debug tools (bind.dnsutils)";
})
  args

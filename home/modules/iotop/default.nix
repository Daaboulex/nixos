# iotop — per-process disk I/O monitor (iotop-c: colorised modern fork).
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "iotop";
  package = p: p.iotop-c;
  description = "iotop-c disk I/O monitor";
})
  args

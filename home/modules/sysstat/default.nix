# sysstat — sar/iostat/pidstat performance monitoring toolkit.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "sysstat";
  description = "sysstat (sar/iostat/pidstat)";
})
  args

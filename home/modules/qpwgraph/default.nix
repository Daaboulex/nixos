{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "qpwgraph";
  description = "qpwgraph PipeWire patchbay";
})
  args

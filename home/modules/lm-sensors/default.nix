{
  config,
  lib,
  pkgs,
  myLib,
  ...
}@args:
(myLib.mkSimplePackage {
  name = "lm-sensors";
  package = p: p.lm_sensors;
  description = "lm_sensors hardware monitoring";
})
  args

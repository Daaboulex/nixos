# msr — x86 MSR access (APERF/MPERF, RAPL energy counters) via /dev/cpu/*/msr.
{ inputs, ... }:
(import ../../lib/mkSimpleNixosModule.nix { lib = inputs.nixpkgs.lib; }) {
  scope = "sensors";
  name = "msr";
  description = "x86 MSR access (APERF/MPERF, RAPL energy counters)";
  config = _: { boot.kernelModules = [ "msr" ]; };
}

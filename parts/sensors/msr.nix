# msr — x86 MSR access (APERF/MPERF, RAPL energy counters) via /dev/cpu/*/msr.
{ inputs, ... }:
let
  mod =
    { config, lib, ... }:
    let
      cfg = config.myModules.sensors.msr;
    in
    {
      _class = "nixos";
      options.myModules.sensors.msr = {
        enable = lib.mkEnableOption "x86 MSR access (APERF/MPERF, RAPL energy counters)";
      };
      config = lib.mkIf cfg.enable {
        boot.kernelModules = [ "msr" ];
      };
    };
in
{
  flake.modules.nixos.sensors-msr = mod;

}

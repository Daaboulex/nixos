# nct6775 — Nuvoton NCT67xx Super I/O sensors (motherboard Vcore, fans, temps).
{ inputs, ... }:
let
  mod =
    { config, lib, ... }:
    let
      cfg = config.myModules.sensors.nct6775;
    in
    {
      _class = "nixos";
      options.myModules.sensors.nct6775 = {
        enable = lib.mkEnableOption "Nuvoton NCT67xx Super I/O sensors (motherboard Vcore, fans, temps)";
      };
      config = lib.mkIf cfg.enable {
        boot.kernelModules = [ "nct6775" ];
      };
    };
in
{
  flake.modules.nixos.sensors-nct6775 = mod;

}

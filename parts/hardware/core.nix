# core — baseline hardware configuration (firmware, microcode updates).
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.hardware.core;
    in
    {
      _class = "nixos";
      options.myModules.hardware.core = {
        enable = lib.mkEnableOption "Core hardware configuration (firmware, microcode)";
      };

      config = lib.mkIf cfg.enable {
        hardware.enableAllFirmware = true;
        services.fwupd.enable = true;

        # CPU microcode
        hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

        # thermald is Intel-only — it conflicts with AMD P-State/Prefcore
        services.thermald.enable = lib.mkDefault (config.myModules.hardware.cpuIntel.enable or false);
        # drivetemp: universal drive-temperature sensor (every host). CPU-temp
        # drivers are the cpu/sensors modules' domain (coretemp Intel / zenpower AMD).
        boot.kernelModules = [ "drivetemp" ];

      };
    };
in
{
  flake.modules.nixos.hardware-core = mod;

}

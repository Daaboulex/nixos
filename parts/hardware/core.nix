{ inputs, ... }:
{
  flake.nixosModules.hardware-core =
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
        enable = lib.mkEnableOption "Core hardware configuration (firmware, microcode, sensors)";
      };

      config = lib.mkIf cfg.enable {
        hardware.enableAllFirmware = true;
        services.fwupd.enable = true;

        # CPU microcode
        hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

        # thermald is Intel-only — it conflicts with AMD P-State/Prefcore
        services.thermald.enable = lib.mkDefault (config.myModules.hardware.cpu.intel.enable or false);
        # coretemp is Intel-only; AMD uses k10temp (loaded by cpu-amd.nix)
        boot.kernelModules = [ "drivetemp" ];
      };
    };
}

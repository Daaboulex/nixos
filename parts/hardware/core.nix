{ inputs, ... }: {
  flake.nixosModules.hardware-core = { config, lib, pkgs, ... }: {
    options.myModules.hardware.core = {
      enable = lib.mkEnableOption "Core hardware configuration (Firmware, Microcode, Sensors)";
    };

    config = lib.mkIf config.myModules.hardware.core.enable {
      hardware.enableAllFirmware = true;
      services.fwupd.enable = true;

      # CPU Microcode
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

      # Common Hardware Sensors and Monitoring
      services.thermald.enable = lib.mkDefault true; # Good for most modern CPUs
      boot.kernelModules = [ "coretemp" "drivetemp" ];
    };
  };
}

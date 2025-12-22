{ config, pkgs, lib, ... }:
let
  mkPkg = mode: if mode == "beta" then config.boot.kernelPackages.nvidiaPackages.beta else config.boot.kernelPackages.nvidiaPackages.stable;
in {
  options.myModules.hardware.graphics.nvidia.enable = lib.mkEnableOption "Nvidia Graphics configuration";
  options.myModules.hardware.graphics.nvidia.profile = {
    mode = lib.mkOption { type = lib.types.enum ["sync" "offload"]; default = "sync"; };
    packageChannel = lib.mkOption { type = lib.types.enum ["beta" "stable"]; default = "beta"; };
    persistenced = lib.mkOption { type = lib.types.bool; default = true; };
    settings = lib.mkOption { type = lib.types.bool; default = true; };
    videoAcceleration = lib.mkOption { type = lib.types.bool; default = true; };
    nvidiaBusId = lib.mkOption { type = lib.types.str; default = ""; };
    intelBusId = lib.mkOption { type = lib.types.str; default = ""; };
    nvregEnable = lib.mkOption { type = lib.types.bool; default = false; };
  };
  config = lib.mkIf config.myModules.hardware.graphics.nvidia.enable (lib.mkMerge [
    {
      hardware.nvidia = let pkg = mkPkg config.myModules.hardware.graphics.nvidia.profile.packageChannel; in {
        open = false;
        package = pkg;
        modesetting.enable = true;
        powerManagement.enable = true;
        powerManagement.finegrained = false;
        dynamicBoost.enable = false;
        prime = if config.myModules.hardware.graphics.nvidia.profile.mode == "sync" then {
          offload.enable = false; offload.enableOffloadCmd = false;
          sync.enable = true; reverseSync.enable = false;
          nvidiaBusId = lib.mkIf (config.myModules.hardware.graphics.nvidia.profile.nvidiaBusId != "") config.myModules.hardware.graphics.nvidia.profile.nvidiaBusId;
          intelBusId = lib.mkIf (config.myModules.hardware.graphics.nvidia.profile.intelBusId != "") config.myModules.hardware.graphics.nvidia.profile.intelBusId;
          allowExternalGpu = true;
        } else {
          offload.enable = true; offload.enableOffloadCmd = true; sync.enable = false; reverseSync.enable = false;
        };
        nvidiaSettings = config.myModules.hardware.graphics.nvidia.profile.settings;
        nvidiaPersistenced = config.myModules.hardware.graphics.nvidia.profile.persistenced;
        forceFullCompositionPipeline = false;
        videoAcceleration = config.myModules.hardware.graphics.nvidia.profile.videoAcceleration;
      };
    }
    (lib.mkIf config.myModules.hardware.graphics.nvidia.profile.nvregEnable {
      boot.extraModprobeConfig = ''
        options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp NVreg_EnableGpuFirmware=1 NVreg_DynamicPowerManagement=0x02
      '';
    })
  ]);
}
# Nvidia vendor module: proprietary driver profile and optional NVreg modprobe
# Example: hardware.nvidia.profile.mode = "sync"; set bus IDs in host
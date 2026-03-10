{ inputs, ... }: {
  flake.nixosModules.hardware-gpu-nvidia = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.hardware.graphics.nvidia;
      mkPkg = mode: if mode == "beta" then config.boot.kernelPackages.nvidiaPackages.beta else config.boot.kernelPackages.nvidiaPackages.stable;
    in {
      _class = "nixos";
      options.myModules.hardware.graphics.nvidia = {
        enable = lib.mkEnableOption "Nvidia Graphics configuration";
        profile = {
          mode = lib.mkOption { type = lib.types.enum ["sync" "offload"]; default = "sync"; description = "PRIME render mode"; };
          packageChannel = lib.mkOption { type = lib.types.enum ["beta" "stable"]; default = "beta"; description = "Nvidia driver channel"; };
          persistenced = lib.mkOption { type = lib.types.bool; default = true; description = "Nvidia persistenced daemon"; };
          settings = lib.mkOption { type = lib.types.bool; default = true; description = "Nvidia settings GUI"; };
          videoAcceleration = lib.mkOption { type = lib.types.bool; default = true; description = "Hardware video acceleration"; };
          nvidiaBusId = lib.mkOption { type = lib.types.str; default = ""; description = "PCI bus ID for Nvidia GPU"; };
          intelBusId = lib.mkOption { type = lib.types.str; default = ""; description = "PCI bus ID for Intel iGPU"; };
          nvregEnable = lib.mkOption { type = lib.types.bool; default = false; description = "NVreg module parameters (VRAM preservation, firmware, power management)"; };
        };
      };

      config = lib.mkIf cfg.enable (lib.mkMerge [
        {
          hardware.nvidia = let pkg = mkPkg cfg.profile.packageChannel; in {
            open = false;
            package = pkg;
            modesetting.enable = true;
            powerManagement.enable = true;
            powerManagement.finegrained = false;
            dynamicBoost.enable = false;
            prime = if cfg.profile.mode == "sync" then {
              offload.enable = false; offload.enableOffloadCmd = false;
              sync.enable = true; reverseSync.enable = false;
              nvidiaBusId = lib.mkIf (cfg.profile.nvidiaBusId != "") cfg.profile.nvidiaBusId;
              intelBusId = lib.mkIf (cfg.profile.intelBusId != "") cfg.profile.intelBusId;
              allowExternalGpu = true;
            } else {
              offload.enable = true; offload.enableOffloadCmd = true; sync.enable = false; reverseSync.enable = false;
            };
            nvidiaSettings = cfg.profile.settings;
            nvidiaPersistenced = cfg.profile.persistenced;
            forceFullCompositionPipeline = false;
            videoAcceleration = cfg.profile.videoAcceleration;
          };
        }
        (lib.mkIf cfg.profile.nvregEnable {
          boot.extraModprobeConfig = ''
            options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp NVreg_EnableGpuFirmware=1 NVreg_DynamicPowerManagement=0x02
          '';
        })
      ]);
    };
}

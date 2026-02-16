{ inputs, ... }: {
  flake.nixosModules.hardware-gpu-amd = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.hardware.graphics.amd;
    in {
      options.myModules.hardware.graphics.amd = {
        enable = lib.mkEnableOption "AMD Graphics configuration";
        
        lact = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable LACT daemon for AMD GPU control/overclocking";
          };
        };

        initrd = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = config.myModules.system.boot.plymouth.enable or false;
            description = "Load amdgpu kernel module in initrd (required for Plymouth)";
          };
        };
        
        enablePPFeatureMask = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable full AMD GPU power management features (ppfeaturemask=0xffffffff)";
        };
      };

      config = lib.mkIf cfg.enable {
        boot.initrd.kernelModules = lib.mkIf cfg.initrd.enable [ "amdgpu" ];
        boot.kernelModules = [ "amdgpu" ];
        
        boot.kernelParams = lib.optionals cfg.enablePPFeatureMask [
          "amdgpu.ppfeaturemask=0xffffffff"
        ];
        
        services.xserver.videoDrivers = [ "amdgpu" ];
        
        environment.systemPackages = lib.mkIf cfg.lact.enable (with pkgs; [
          lact
          corectrl
        ]);
        
        systemd.services.lactd = lib.mkIf cfg.lact.enable {
          description = "AMDGPU Control Daemon";
          after = [ "multi-user.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${pkgs.lact}/bin/lact daemon";
            Restart = "always";
          };
        };
        
        hardware.enableRedistributableFirmware = true;
      };
    };
}

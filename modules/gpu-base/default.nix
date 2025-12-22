{ config, pkgs, lib, ... }:
let
  cfg = config.myModules.hardware.graphics;
in {
  options.myModules.hardware.graphics = {
    enable = lib.mkEnableOption "Graphics configuration";
    enable32Bit = lib.mkEnableOption "Enable 32-bit graphics libraries for Steam/Wine";
  };

  config = lib.mkIf cfg.enable {
    services.xserver.videoDrivers = lib.mkOptionDefault [ "modesetting" ];
    hardware.graphics.enable = true;
    
    hardware.graphics.extraPackages = with pkgs; 
      # Common packages for all systems
      [ libvdpau-va-gl mesa vulkan-loader vulkan-tools ]
      
      # Intel-specific packages
      ++ lib.optionals (config.myModules.hardware.graphics.intel.enable or false) [
        intel-media-driver
        intel-vaapi-driver
      ]
      
      # Nvidia-specific packages  
      ++ lib.optionals (config.myModules.hardware.graphics.nvidia.enable or false) [
        nvidia-vaapi-driver
      ];

    # 32-bit graphics support (for Steam/Wine)
    hardware.graphics.enable32Bit = cfg.enable32Bit;
    hardware.graphics.extraPackages32 = lib.mkIf cfg.enable32Bit (
      (with pkgs.driversi686Linux; [ mesa ])
      ++ lib.optionals (config.myModules.hardware.graphics.nvidia.enable or false) [
        config.boot.kernelPackages.nvidiaPackages.beta.lib32
      ]
    );
  };
}
# Graphics base: common userspace and 32-bit support
# Example: myModules.hardware.graphics = { enable = true; enable32Bit = true; };
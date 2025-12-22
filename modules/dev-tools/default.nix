{ config, pkgs, lib, ... }:
let
  cfg = config.myModules.development.tools;
in {
  options.myModules.development.tools = {
    enable = lib.mkEnableOption "Development Tools (IDEs, Compilers, Runtimes)";
    helperScripts = lib.mkEnableOption "Enable helper scripts (llm-prep, list-iommu-groups, list-gpu-drivers)";
  };

  config = lib.mkIf cfg.enable {
    # Enable the helper script modules when helperScripts is enabled
    myModules.tools = lib.mkIf cfg.helperScripts {
      llmPrep.enable = true;
      listIommuGroups.enable = true;
      listGpuDrivers.enable = true;
    };

    environment.systemPackages = with pkgs; [
      # IDEs & Editors
      vscodium
      google-antigravity
      
      # Environment Tools
      direnv
      devenv
      nix-prefetch-git

      # Saleae Logic 2
      saleae-logic-2
      
      # Compilers & Build Tools
      gnumake
      cmake
      pkg-config
      gcc
      
      # Runtimes
      python3
      nodejs
    ];

    # Udev rules for hardware debugging
    services.udev.packages = with pkgs; [ saleae-logic-2 ];

    services.udev.extraRules = ''
      # NXP LPC-LINK2 CMSIS-DAP - USB device
      SUBSYSTEM=="usb", ATTR{idVendor}=="1fc9", MODE="0666", GROUP="users"

      # NXP LPC-LINK2 CMSIS-DAP - HID interface (required for CMSIS-DAP)
      KERNEL=="hidraw*", ATTRS{idVendor}=="1fc9", MODE="0666", GROUP="users"
    '';
    
    # Disable OpenSSH by default (enable in host config if needed)
    services.openssh.enable = lib.mkDefault false;
  };
}
# Development Tools Module
# Handles IDEs, compilers, runtimes, and helper scripts
# Helper scripts are now managed via myModules.tools.*
{
  imports = [
    ./overlays.nix
    
    # System Modules
    ./system/boot.nix
    ./system/kernel.nix
    ./system/nix.nix
    ./system/users.nix
    ./system/security.nix
    
    # Hardware Modules
    ./hardware/cpu-amd.nix
    ./hardware/cpu-intel.nix
    ./hardware/gpu-amd.nix
    ./hardware/gpu-intel.nix
    ./hardware/gpu-nvidia.nix
    ./hardware/graphics.nix
    ./hardware/audio.nix
    ./hardware/networking.nix
    ./hardware/bluetooth.nix
    ./hardware/core.nix
    
    # Desktop & Apps
    ./desktop/kde.nix
    ./desktop/displays.nix
    ./desktop/flatpak.nix
    
    ./apps/arkenfox.nix
    ./apps/portmaster.nix
    ./apps/tidalcycles.nix
    ./apps/wine.nix
    ./apps/tools/sysdiag.nix
    ./apps/tools/iommu.nix
    ./apps/tools/development.nix
    
    ./system/cachyos-settings.nix
    ./system/filesystems.nix
    ./system/packages.nix
    ./system/ssh.nix
    ./system/sops.nix
    ./system/services.nix
    
    ./apps/gaming.nix

    # Drivers/Hardware Extras
    ./hardware/goxlr.nix
    ./hardware/piper.nix
    ./hardware/streamcontroller.nix
    ./hardware/macbook/default.nix
    ./hardware/performance.nix
    ./hardware/power.nix
    ./hardware/yeetmouse/default.nix
    
    # Hosts
    ./hosts/ryzen-9950x3d/flake-module.nix
    ./hosts/macbook-pro-9-2/flake-module.nix
  ];

  perSystem = { config, self', inputs', pkgs, system, ... }: {
    # Per-system configuration if needed (e.g. devShells, packages)
    # packages = import ./pkgs { inherit pkgs; };
  };
}

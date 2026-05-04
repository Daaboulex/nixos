# flake-module — nixosConfiguration + module imports + overlays for ryzen-9950x3d.
#
# exhaustiveness-exclude:
#   hardware-cpu-intel hardware-gpu-intel hardware-gpu-nvidia
#   macbook-hid-apple macbook-mbpfan macbook-patches macbook-wifi
#   sensors-it87
#
# Modules above are Intel/NVIDIA/MacBook-specific and intentionally not
# imported on the Ryzen workstation. The nixos-exhaustiveness hook
# skips them for this host.
{ inputs, ... }:
{
  flake.nixosConfigurations.ryzen-9950x3d = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit inputs;
      myLib = inputs.self.lib;
      site = import inputs.site;
    };
    modules = [
      # Host config
      ./default.nix

      # Dendritic modules
      (
        { config, ... }:
        {
          imports = [
            # Boot
            inputs.self.modules.nixos.boot-boot
            inputs.self.modules.nixos.boot-hibernate
            inputs.self.modules.nixos.boot-impermanence
            inputs.self.modules.nixos.boot-kernel

            # Nix
            inputs.self.modules.nixos.host
            inputs.self.modules.nixos.nix-nix
            inputs.self.modules.nixos.nix-nix-ld
            inputs.self.modules.nixos.nix-remote-builder

            # Users
            inputs.self.modules.nixos.users

            # Storage
            inputs.self.modules.nixos.storage-btrbk
            inputs.self.modules.nixos.storage-filesystems
            inputs.self.modules.nixos.storage-fstrim

            # Services
            inputs.self.modules.nixos.services-avahi
            inputs.self.modules.nixos.services-cups
            inputs.self.modules.nixos.services-earlyoom
            inputs.self.modules.nixos.services-geoclue
            inputs.self.modules.nixos.services-mullvad
            inputs.self.modules.nixos.services-sunshine
            inputs.self.modules.nixos.services-syncthing

            # Security
            inputs.self.modules.nixos.security-hardening
            inputs.self.modules.nixos.security-ssh
            inputs.self.modules.nixos.security-agenix
            inputs.self.modules.nixos.security-portmaster
            inputs.self.modules.nixos.security-portmaster-mullvad-compat

            # Hardware
            inputs.self.modules.nixos.hardware-core
            inputs.self.modules.nixos.hardware-cpu-amd
            inputs.self.modules.nixos.hardware-gpu-amd
            inputs.self.modules.nixos.hardware-graphics
            inputs.self.modules.nixos.hardware-pipewire
            inputs.self.modules.nixos.hardware-usb-power
            inputs.self.modules.nixos.hardware-networking
            inputs.self.modules.nixos.hardware-bluetooth
            inputs.self.modules.nixos.hardware-power
            inputs.self.modules.nixos.hardware-udev-access
            inputs.self.modules.nixos.hardware-acpid
            inputs.self.modules.nixos.hardware-upower
            inputs.self.modules.nixos.hardware-usbmuxd

            # Tuning
            inputs.self.modules.nixos.tuning-cachyos
            inputs.self.modules.nixos.tuning-corecycler
            inputs.self.modules.nixos.tuning-performance
            inputs.self.modules.nixos.tuning-sysctls

            # Diagnostics
            inputs.self.modules.nixos.diagnostics-turbostat

            # Sensors
            inputs.self.modules.nixos.sensors-nct6775
            inputs.self.modules.nixos.sensors-zenpower
            inputs.self.modules.nixos.sensors-ryzen-smu
            inputs.self.modules.nixos.sensors-msr

            # Desktop
            inputs.self.modules.nixos.desktop-plasma
            inputs.self.modules.nixos.desktop-displays
            inputs.self.modules.nixos.desktop-flatpak

            # Input
            inputs.self.modules.nixos.input-ducky-one-x-mini
            inputs.self.modules.nixos.input-libinput
            inputs.self.modules.nixos.input-ratbagd
            inputs.self.modules.nixos.input-streamcontroller
            inputs.self.modules.nixos.input-yeetmouse

            # Diagnostics

            # GoXLR
            inputs.self.modules.nixos.hardware-goxlr

            # Gaming
            inputs.self.modules.nixos.gaming-steam
            inputs.self.modules.nixos.gaming-gamescope
            inputs.self.modules.nixos.gaming-gamemode
            inputs.self.modules.nixos.gaming-rocksmith

            # VFIO
            inputs.self.modules.nixos.vfio-base
            inputs.self.modules.nixos.vfio-session-gpu
            inputs.self.modules.nixos.vfio-device-binding
            inputs.self.modules.nixos.vfio-kvmfr
            inputs.self.modules.nixos.vfio-evdev
            inputs.self.modules.nixos.vfio-hugepages
            inputs.self.modules.nixos.vfio-vms

            # Standalone
            inputs.self.modules.nixos.hardware-coolercontrol

            # External modules
            inputs.vfio-stealth.nixosModules.default
            inputs.portmaster.nixosModules.default
            inputs.cachyos-settings-nix.nixosModules.default
            inputs.NixVirt.nixosModules.default
            inputs.impermanence.nixosModules.impermanence
            inputs.yeetmouse-nix.nixosModules.default
            inputs.gemini-cli-nix.nixosModules.default
            inputs.openviking.nixosModules.default
            inputs.lmstudio.nixosModules.default
            # CoolerControl: overlay provides 4.0.1 packages, nixpkgs module handles the rest
          ];
        }
      )

      # Home Manager
      ../../../home/home.nix
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {
          inherit inputs;
          myLib = inputs.self.lib;
          site = import inputs.site;
        };
        home-manager.sharedModules = [
          inputs.goxlr-hm-nix.homeManagerModules.default
          inputs.yeetmouse-nix.homeManagerModules.default
          inputs.streamcontroller-nix.homeManagerModules.default
          inputs.coolercontrol.homeManagerModules.default
          inputs.lmstudio.homeManagerModules.default
          inputs.rocksmith-nix.homeManagerModules.default
        ];
      }

      # External modules
      inputs.nix-flatpak.nixosModules.nix-flatpak
      inputs.lanzaboote.nixosModules.lanzaboote
      inputs.agenix.nixosModules.default
      # Disko: declarative disk layout for new installations
      # Import disko module for `disko` CLI availability; the disk layout in
      # disko.nix is only used at install time (not imported here to avoid
      # conflicting fileSystems definitions with hardware-configuration.nix).
      inputs.disko.nixosModules.disko

      # Overlays — composed once in parts/_build/overlays.nix and reused
      # by perSystem.pkgs + every host, so checks.* and nixosConfigurations.*
      # see identical package sets.
      {
        nixpkgs.hostPlatform = "x86_64-linux";
        nixpkgs.config.allowUnfree = true;
        nixpkgs.overlays = [ inputs.self.overlays.default ];
      }
    ];
  };
}

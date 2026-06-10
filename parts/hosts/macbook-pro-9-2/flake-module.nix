# flake-module — nixosConfiguration + module imports + overlays for macbook-pro-9-2.
#
# exhaustiveness-exclude:
#   gaming-gamemode gaming-gamescope gaming-rocksmith gaming-steam
#   hardware-coolercontrol hardware-cpu-amd hardware-goxlr hardware-gpu-amd hardware-gpu-nvidia
#   hardware-multiseat
#   input-ducky-one-x-mini input-ratbagd input-streamcontroller input-yeetmouse
#   nix-nix-ld
#   sensors-it87 sensors-msr sensors-nct6775 sensors-ryzen-smu sensors-zenpower
#   tuning-corecycler
#   vfio-device-binding vfio-evdev vfio-hugepages vfio-kvmfr vfio-session-gpu vfio-vms
#
# Modules above are AMD/Ryzen/workstation-specific and intentionally not
# imported on MBP 9,2. The nixos-exhaustiveness hook skips them for this host.
{ inputs, ... }:
{
  flake.nixosConfigurations.macbook-pro-9-2 = inputs.nixpkgs.lib.nixosSystem {
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
            inputs.self.modules.nixos.boot-loader
            inputs.self.modules.nixos.boot-hibernate
            inputs.self.modules.nixos.boot-impermanence
            inputs.self.modules.nixos.boot-kernel

            # Nix
            inputs.self.modules.nixos.host
            inputs.self.modules.nixos.nix-nix
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

            # Hardware (Intel — no AMD modules)
            inputs.self.modules.nixos.hardware-core
            inputs.self.modules.nixos.hardware-cpu-intel
            inputs.self.modules.nixos.hardware-gpu-intel
            inputs.self.modules.nixos.hardware-graphics
            inputs.self.modules.nixos.hardware-pipewire
            inputs.self.modules.nixos.hardware-usb-power
            inputs.self.modules.nixos.hardware-networking
            inputs.self.modules.nixos.hardware-bluetooth
            inputs.self.modules.nixos.hardware-power
            inputs.self.modules.nixos.hardware-acpid
            inputs.self.modules.nixos.hardware-upower
            inputs.self.modules.nixos.hardware-udev-access
            inputs.self.modules.nixos.hardware-usbmuxd

            # Tuning
            inputs.self.modules.nixos.tuning-cachyos
            inputs.self.modules.nixos.tuning-performance
            inputs.self.modules.nixos.tuning-sysctls

            # Diagnostics
            inputs.self.modules.nixos.diagnostics-turbostat

            # Desktop
            inputs.self.modules.nixos.desktop-plasma
            inputs.self.modules.nixos.desktop-displays
            inputs.self.modules.nixos.desktop-flatpak

            # Input
            inputs.self.modules.nixos.input-libinput

            # Apple hardware
            inputs.self.modules.nixos.hardware-hid-apple
            inputs.self.modules.nixos.hardware-mbpfan
            inputs.self.modules.nixos.hardware-broadcom-wifi
            inputs.self.modules.nixos.vfio-base

            # External modules
            inputs.portmaster.nixosModules.default
            inputs.cachyos-settings-nix.nixosModules.default
            inputs.NixVirt.nixosModules.default
            inputs.impermanence.nixosModules.impermanence
            inputs.openviking.nixosModules.default
            inputs.lmstudio.nixosModules.default
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
          inputs.lmstudio.homeManagerModules.default
          inputs.rocksmith-nix.homeManagerModules.default
        ];
      }

      # External modules
      inputs.nix-flatpak.nixosModules.nix-flatpak
      inputs.lanzaboote.nixosModules.lanzaboote
      inputs.refind-nix.nixosModules.default
      inputs.agenix.nixosModules.default
      # Disko: declarative disk layout for new installations
      # Import disko module for `disko` CLI availability; the disk layout in
      # disko.nix is only used at install time (not imported here to avoid
      # conflicting fileSystems definitions with hardware-configuration.nix).
      inputs.disko.nixosModules.disko

      # Overlays
      # Overlays — composed once in parts/_build/overlays.nix. Listing all
      # inputs' overlays is safe: overlays are lazy, unused attrs don't
      # evaluate. Keeps perSystem.pkgs + every host on identical pkgs.
      {
        nixpkgs.hostPlatform = "x86_64-linux";
        nixpkgs.config.allowUnfree = true;
        nixpkgs.overlays = [
          inputs.self.overlays.default
          inputs.refind-nix.overlays.default
        ];
      }

      # Single CachyOS kernel — no specialisations (configured in default.nix)
      { }
    ];
  };
}

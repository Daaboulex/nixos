{ inputs, ... }:
{
  flake.nixosConfigurations.ryzen-9950x3d = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      # Host config
      ./default.nix

      # Dendritic modules
      (
        { config, ... }:
        {
          imports = [
            # System
            inputs.self.nixosModules.system-boot
            inputs.self.nixosModules.system-kernel
            inputs.self.nixosModules.system-nix
            inputs.self.nixosModules.system-users
            inputs.self.nixosModules.system-filesystems
            inputs.self.nixosModules.system-impermanence
            inputs.self.nixosModules.system-services
            inputs.self.nixosModules.system-packages

            # Security
            inputs.self.nixosModules.security-hardening
            inputs.self.nixosModules.security-ssh
            inputs.self.nixosModules.security-sops
            inputs.self.nixosModules.security-arkenfox
            inputs.self.nixosModules.security-portmaster

            # Hardware
            inputs.self.nixosModules.hardware-core
            inputs.self.nixosModules.hardware-cpu-amd
            inputs.self.nixosModules.hardware-gpu-amd
            inputs.self.nixosModules.hardware-graphics
            inputs.self.nixosModules.hardware-audio
            inputs.self.nixosModules.hardware-networking
            inputs.self.nixosModules.hardware-bluetooth
            inputs.self.nixosModules.hardware-sensors
            inputs.self.nixosModules.hardware-performance
            inputs.self.nixosModules.hardware-power

            # Desktop
            inputs.self.nixosModules.desktop-kde
            inputs.self.nixosModules.desktop-displays
            inputs.self.nixosModules.desktop-flatpak

            # Input
            inputs.self.nixosModules.input-yeetmouse
            inputs.self.nixosModules.input-piper
            inputs.self.nixosModules.input-streamcontroller
            inputs.self.nixosModules.input-ducky-one-x-mini

            # Diagnostics
            inputs.self.nixosModules.diagnostics-sysdiag
            inputs.self.nixosModules.diagnostics-iommu
            inputs.self.nixosModules.diagnostics-corecycler

            # Standalone
            inputs.self.nixosModules.development-debugging-probes
            inputs.self.nixosModules.coolercontrol
            inputs.self.nixosModules.goxlr
            inputs.self.nixosModules.gaming
            inputs.self.nixosModules.gaming-wine
            inputs.self.nixosModules.tidalcycles
            inputs.self.nixosModules.development
            inputs.self.nixosModules.vfio

            # System (CachyOS)
            inputs.self.nixosModules.system-cachyos

            # External modules
            inputs.portmaster.nixosModules.default
            inputs.cachyos-settings-nix.nixosModules.default
            inputs.NixVirt.nixosModules.default
            inputs.impermanence.nixosModules.impermanence
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
        home-manager.extraSpecialArgs = { inherit inputs; };
      }

      # External modules
      inputs.nix-flatpak.nixosModules.nix-flatpak
      inputs.lanzaboote.nixosModules.lanzaboote
      inputs.sops-nix.nixosModules.sops
      # Disko: declarative disk layout for new installations
      # Import disko module for `disko` CLI availability; the disk layout in
      # disko.nix is only used at install time (not imported here to avoid
      # conflicting fileSystems definitions with hardware-configuration.nix).
      inputs.disko.nixosModules.disko

      # Overlays
      {
        nixpkgs.hostPlatform = "x86_64-linux";
        nixpkgs.config.allowUnfree = true;
        nixpkgs.overlays = [
          inputs.self.overlays.default
          inputs.nix-cachyos-kernel.overlays.pinned
          inputs.tidalcycles.overlays.default
          inputs.antigravity.overlays.default
          inputs.nx-save-sync.overlays.default
          inputs.portmaster.overlays.default
          inputs.occt-nix.overlays.default
          inputs.claude-code.overlays.default
          inputs.lsfg-vk.overlays.default
          inputs.vkbasalt-overlay.overlays.default
          inputs.mesa-git-nix.overlays.default
          inputs.coolercontrol.overlays.default
        ];
      }
    ];
  };
}

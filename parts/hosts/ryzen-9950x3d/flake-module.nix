{ inputs, ... }: {
  flake.nixosConfigurations.ryzen-9950x3d = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      # Host config
      ./default.nix

      # Dendritic modules
      ({ config, ... }: {
        imports = [
          # System
          inputs.self.nixosModules.system-boot
          inputs.self.nixosModules.system-kernel
          inputs.self.nixosModules.system-nix
          inputs.self.nixosModules.system-users
          inputs.self.nixosModules.system-security
          inputs.self.nixosModules.system-filesystems
          inputs.self.nixosModules.system-ssh
          inputs.self.nixosModules.system-sops
          inputs.self.nixosModules.system-impermanence
          inputs.self.nixosModules.system-services
          inputs.self.nixosModules.system-packages

          # Hardware
          inputs.self.nixosModules.hardware-core
          inputs.self.nixosModules.hardware-cpu-amd
          inputs.self.nixosModules.hardware-gpu-amd
          inputs.self.nixosModules.hardware-graphics
          inputs.self.nixosModules.hardware-audio
          inputs.self.nixosModules.hardware-networking
          inputs.self.nixosModules.hardware-bluetooth
          inputs.self.nixosModules.hardware-yeetmouse
          inputs.self.nixosModules.hardware-goxlr
          inputs.self.nixosModules.hardware-piper
          inputs.self.nixosModules.hardware-streamcontroller
          inputs.self.nixosModules.hardware-ducky-one-x-mini
          inputs.self.nixosModules.hardware-performance
          inputs.self.nixosModules.hardware-power

          # Desktop
          inputs.self.nixosModules.desktop-kde
          inputs.self.nixosModules.desktop-displays
          inputs.self.nixosModules.desktop-flatpak

          # Apps
          inputs.self.nixosModules.apps-gaming
          inputs.self.nixosModules.apps-arkenfox
          inputs.self.nixosModules.apps-portmaster
          inputs.self.nixosModules.apps-tidalcycles
          inputs.self.nixosModules.apps-wine
          inputs.self.nixosModules.apps-development

          # Tools
          inputs.self.nixosModules.tools-sysdiag
          inputs.self.nixosModules.tools-iommu

          # CachyOS settings
          inputs.self.nixosModules.cachyos-settings

          # External modules
          inputs.portmaster.nixosModules.default
          inputs.cachyos-settings-nix.nixosModules.default
          inputs.impermanence.nixosModules.impermanence
        ];
      })

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
        ];
      }
    ];
  };
}

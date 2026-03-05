{ inputs, ... }: {
  flake.nixosConfigurations.ryzen-9950x3d = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      # Host Specific Config (imported from local directory)
      ./default.nix
      
      # Dendritic Parts Modules (Using the flake config)
      ({ config, ... }: {
        imports = [
          # System
          inputs.self.nixosModules.system-boot
          inputs.self.nixosModules.system-kernel
          inputs.self.nixosModules.system-nix
          inputs.self.nixosModules.system-users
          inputs.self.nixosModules.system-security
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
          inputs.self.nixosModules.hardware-performance
          inputs.self.nixosModules.hardware-power
          
          # Desktop & Apps
          inputs.self.nixosModules.desktop-kde
          inputs.self.nixosModules.desktop-displays
          inputs.self.nixosModules.desktop-flatpak
          inputs.self.nixosModules.apps-gaming
          
          inputs.self.nixosModules.system-filesystems
          inputs.self.nixosModules.system-ssh
          inputs.self.nixosModules.system-sops
          inputs.self.nixosModules.system-services
          
          inputs.self.nixosModules.apps-arkenfox
          inputs.portmaster.nixosModules.default
          inputs.self.nixosModules.apps-portmaster
          inputs.self.nixosModules.apps-tidalcycles
          inputs.self.nixosModules.apps-wine
          inputs.self.nixosModules.apps-tools
          
          inputs.self.nixosModules.system-packages
          inputs.cachyos-settings-nix.nixosModules.default
          inputs.self.nixosModules.cachyos-settings
        ];
      })

      # Legacy Home Configuration (Shared)
      ../../../home/home.nix
      
      # External Modules
      inputs.nix-flatpak.nixosModules.nix-flatpak
      inputs.home-manager.nixosModules.home-manager
      inputs.lanzaboote.nixosModules.lanzaboote
      inputs.sops-nix.nixosModules.sops

      # Home Manager Configuration
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { inherit inputs; };
      }

      # Overlays (Explicitly included here for now, or use the overlay part if mapped)
      {
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
          inputs.mesa-git-nix.overlays.default
        ];
      }
    ];
  };
}

{ inputs, ... }:
{
  flake.nixosConfigurations.macbook-pro-9-2 = inputs.nixpkgs.lib.nixosSystem {
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

            # Hardware (Intel — no AMD modules)
            inputs.self.nixosModules.hardware-core
            inputs.self.nixosModules.hardware-cpu-intel
            inputs.self.nixosModules.hardware-gpu-intel
            inputs.self.nixosModules.hardware-graphics
            inputs.self.nixosModules.hardware-audio
            inputs.self.nixosModules.hardware-networking
            inputs.self.nixosModules.hardware-bluetooth
            inputs.self.nixosModules.hardware-performance
            inputs.self.nixosModules.hardware-power

            # Desktop
            inputs.self.nixosModules.desktop-kde
            inputs.self.nixosModules.desktop-displays
            inputs.self.nixosModules.desktop-flatpak

            # Standalone
            inputs.self.nixosModules.macbook
            inputs.self.nixosModules.gaming-wine
            inputs.self.nixosModules.tidalcycles
            inputs.self.nixosModules.development

            # Diagnostics
            inputs.self.nixosModules.diagnostics-sysdiag
            inputs.self.nixosModules.diagnostics-iommu

            # CachyOS settings
            inputs.self.nixosModules.system-cachyos

            # External modules
            inputs.portmaster.nixosModules.default
            inputs.cachyos-settings-nix.nixosModules.default
            inputs.impermanence.nixosModules.impermanence
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
      # CachyOS kernel overlay included unconditionally — exposes pkgs.cachyosKernels.*
      # for specialisations to switch kernel variants without a different pkgs fixpoint
      {
        nixpkgs.hostPlatform = "x86_64-linux";
        nixpkgs.config.allowUnfree = true;
        nixpkgs.overlays = [
          inputs.self.overlays.default
          inputs.tidalcycles.overlays.default
          inputs.antigravity.overlays.default
          inputs.portmaster.overlays.default
          inputs.claude-code.overlays.default
          inputs.nix-cachyos-kernel.overlays.pinned
        ];
      }

      # Kernel variant specialisations
      # Each creates a separate boot entry in systemd-boot.
      # One `nrb` builds all 3 variants — select another from boot menu if active breaks.
      {
        specialisation = {
          # Xanmod: optimized kernel (better latency, newer patches)
          xanmod.configuration = {
            system.nixos.tags = [ "xanmod" ];
            myModules.system.kernel.variant = "xanmod";
            myModules.macbook.patches.enable = false;
          };

          # CachyOS: full CachyOS kernel + optimizations
          cachyos.configuration = {
            system.nixos.tags = [ "cachyos" ];
            myModules.system.kernel.variant = "cachyos";
            myModules.macbook.patches.enable = false;
            myModules.system.kernel.cachyos = {
              bbr3 = true;
              hzTicks = "1000";
              tickrate = "full";
              preemptType = "full";
              ccHarder = true;
              hugepage = "always";
            };
          };
        };
      }
    ];
  };
}

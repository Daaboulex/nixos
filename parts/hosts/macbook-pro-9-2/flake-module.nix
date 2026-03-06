{ inputs, ... }: {
  flake.nixosConfigurations.macbook-pro-9-2 = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      # Host Specific Config
      ./default.nix

      # Dendritic Parts Modules
      ({ config, ... }: {
        imports = [
          # System
          inputs.self.nixosModules.system-boot
          inputs.self.nixosModules.system-kernel
          inputs.self.nixosModules.system-nix
          inputs.self.nixosModules.system-users
          inputs.self.nixosModules.system-security

          # Hardware (Intel — no AMD modules)
          inputs.self.nixosModules.hardware-core
          inputs.self.nixosModules.hardware-cpu-intel
          inputs.self.nixosModules.hardware-gpu-intel
          inputs.self.nixosModules.hardware-graphics
          inputs.self.nixosModules.hardware-audio
          inputs.self.nixosModules.hardware-networking
          inputs.self.nixosModules.hardware-bluetooth
          inputs.self.nixosModules.hardware-macbook
          inputs.self.nixosModules.hardware-performance
          inputs.self.nixosModules.hardware-power

          # Desktop & Apps
          inputs.self.nixosModules.desktop-kde
          inputs.self.nixosModules.desktop-displays
          inputs.self.nixosModules.desktop-flatpak

          inputs.self.nixosModules.system-filesystems
          inputs.self.nixosModules.system-ssh
          inputs.self.nixosModules.system-sops
          inputs.self.nixosModules.system-services

          inputs.self.nixosModules.apps-arkenfox
          inputs.portmaster.nixosModules.default
          inputs.self.nixosModules.apps-portmaster
          inputs.self.nixosModules.apps-tidalcycles
          inputs.self.nixosModules.apps-wine
          inputs.self.nixosModules.tools-sysdiag
          inputs.self.nixosModules.tools-iommu

          inputs.self.nixosModules.apps-development

          inputs.self.nixosModules.system-packages
          inputs.cachyos-settings-nix.nixosModules.default
          inputs.self.nixosModules.cachyos-settings
        ];
      })

      # Home Manager (auto-discovers host via hostname)
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

      # Overlays
      # CachyOS kernel overlay is included unconditionally — it only exposes
      # packages in pkgs.cachyosKernels.*, which are unused unless
      # kernel.variant = "cachyos". This allows specialisations to switch
      # kernel variants without needing a different pkgs fixpoint.
      {
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

      # ================================================================
      # Kernel Variant Specialisations
      # ================================================================
      # Each specialisation creates a separate boot entry in systemd-boot.
      # One `nrb` builds all 3 variants — if the active kernel breaks,
      # select another variant from the boot menu.
      # ================================================================
      {
        specialisation = {
          # Xanmod: optimized kernel (better latency, newer patches)
          # applesmc/at24 patches not needed — xanmod includes upstream fixes
          xanmod.configuration = {
            system.nixos.tags = [ "xanmod" ];
            myModules.kernel.variant = "xanmod";
            myModules.hardware.macbook.patches.enable = false;
          };

          # CachyOS: full CachyOS kernel + optimizations
          # Patches disabled for first build to test if CachyOS already includes fixes
          cachyos.configuration = {
            system.nixos.tags = [ "cachyos" ];
            myModules.kernel.variant = "cachyos";
            myModules.hardware.macbook.patches.enable = false;
            myModules.kernel.cachyos = {
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

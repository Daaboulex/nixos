{
  description = "Modular NixOS configurations with flakes";

  # ============================================================================
  # Inputs - External dependencies and package sources
  # ============================================================================
  inputs = {
    # Core NixOS packages - using unstable channel for latest packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Chaotic-Nyx - CachyOS kernels and optimized packages
    chaotic.url = "https://flakehub.com/f/chaotic-cx/nyx/*.tar.gz";

    # TidalCycles - Live coding music environment
    tidalcycles.url = "github:mitchmindtree/tidalcycles.nix";

    # Home Manager - User environment management
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative Flatpak management
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    # Lanzaboote - Secure Boot for NixOS
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    yeetmouse-src = {
      url = "github:AndyFilter/YeetMouse";
      flake = false;
    };

    # YeetMouse - Mouse acceleration/sensitivity tool
    yeetmouse = {
      url = "github:AndyFilter/YeetMouse?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # CachyOS Settings - System optimization configurations
    cachyos-settings = {
      url = "github:CachyOS/CachyOS-Settings";
      flake = false;
    };

    # sops-nix - Secrets management with SOPS
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Plasma Manager - KDE Plasma configuration via Home Manager
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Eden - Nintendo Switch emulator (community fork)
    eden = {
      url = "github:daaboulex/eden-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # ============================================================================
  # Outputs - System configurations and overlays
  # ============================================================================
  outputs = { self, ... }@inputs:
  let
    # System architecture
    system = "x86_64-linux";

    # Package set with overlays applied
    pkgs = import inputs.nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;  # Enable proprietary packages (NVIDIA, etc.)
      };
      overlays = [
        (import ./overlays { inherit inputs; })
        inputs.chaotic.overlays.default
        inputs.tidalcycles.overlays.default
        (final: prev: {
          google-antigravity = final.callPackage ./modules/antigravity/package.nix { };
        })
      ];
    };

    # Helper function to create NixOS system configurations
    mkHost = { hostname }:
      inputs.nixpkgs.lib.nixosSystem {
        inherit pkgs system;
        specialArgs = { inherit inputs; };
        modules = [
          # External modules
          inputs.chaotic.nixosModules.default
          inputs.nix-flatpak.nixosModules.nix-flatpak
          inputs.home-manager.nixosModules.home-manager
          inputs.lanzaboote.nixosModules.lanzaboote
          inputs.sops-nix.nixosModules.sops

          # Pass inputs to Home Manager for plasma-manager access
          {
            home-manager.useGlobalPkgs = true;   # Use system nixpkgs (saves eval, adds consistency)
            home-manager.useUserPackages = true; # Install to /etc/profiles (required for build-vm)
            home-manager.extraSpecialArgs = { inherit inputs; };
          }

          # Host-specific configuration
          ./hosts/${hostname}/default.nix

          # Shared modules
          ./modules/default.nix
          ./home/home.nix
        ];
      };
  in {
    # NixOS system configurations
    nixosConfigurations = {
      macbook-pro-9-2 = mkHost { hostname = "macbook-pro-9-2"; };
      ryzen-9950x3d = mkHost { hostname = "ryzen-9950x3d"; };
    };

    # Export overlays for reuse
    overlays.default = import ./overlays { inherit inputs; };
  };
}

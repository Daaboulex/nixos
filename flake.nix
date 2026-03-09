{
  description = "Modular NixOS configurations with flakes";

  # ============================================================================
  # Inputs - External dependencies and package sources
  # ============================================================================
  inputs = {
    # Core NixOS packages - using unstable channel for latest packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Flake Parts - Modular flake framework
    flake-parts.url = "github:hercules-ci/flake-parts";

    # nix-cachyos-kernel - CachyOS kernel provider
    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel";
      # Do not override its nixpkgs input, otherwise there can be mismatch between patches and kernel version
    };

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

    # CachyOS Settings - System optimization configurations (NixOS module)
    cachyos-settings-nix = {
      url = "github:Daaboulex/cachyos-settings-nix";
      inputs.nixpkgs.follows = "nixpkgs";
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

    # NX-Save-Sync - Switch save sync tool
    nx-save-sync = {
      url = "github:daaboulex/nx-save-sync-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Google Antigravity - Agentic IDE (upstream maintained by jacopone)
    antigravity = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Portmaster - Privacy Application (Local Flake)
    portmaster = {
      url = "github:daaboulex/portmaster-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # OCCT - Stability Test & Benchmark (Local Flake)
    occt-nix = {
      url = "github:daaboulex/OCCT-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Code - AI coding assistant (Always up-to-date)
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Mesa-git - Bleeding-edge Mesa from main branch
    mesa-git-nix = {
      url = "github:daaboulex/mesa-git-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # LSFG-VK - Vulkan Frame Generation (Lossless Scaling)
    lsfg-vk = {
      url = "github:daaboulex/lsfg-vk-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # vkBasalt Overlay - Vulkan post-processing layer with in-game UI (Wayland + X11)
    vkbasalt-overlay = {
      url = "github:Daaboulex/vkBasalt_overlay_wayland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # ============================================================================
  # Outputs - System configurations and overlays
  # ============================================================================
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ ./parts/flake-module.nix ];
      
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
            inputs.portmaster.overlays.default
          ];
          config.allowUnfree = true;
        };
      };
    };
}

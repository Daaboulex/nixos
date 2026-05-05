{
  description = "Modular NixOS configurations with flakes";

  # ============================================================================
  # Inputs - External dependencies and package sources
  # ============================================================================
  inputs = {
    # Core NixOS packages - using unstable channel for latest packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Extensions for VS Code based ide's
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Flake Parts - Modular flake framework
    flake-parts.url = "github:hercules-ci/flake-parts";

    # nix-cachyos-kernel - CachyOS kernel provider
    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel";
      # Do not override its nixpkgs input, otherwise there can be mismatch between patches and kernel version
    };

    # TidalCycles - Live coding music environment
    tidalcycles = {
      url = "github:mitchmindtree/tidalcycles.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    # YeetMouse — kernel mouse acceleration driver with GUI
    yeetmouse-nix = {
      url = "github:Daaboulex/yeetmouse-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # CachyOS Settings - System optimization configurations (NixOS module)
    cachyos-settings-nix = {
      url = "github:Daaboulex/cachyos-settings-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # agenix — age-encrypted secrets using host SSH keys.
    agenix = {
      url = "github:ryantm/agenix";
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

    # Mullvad VPN - declarative daemon + GUI prefs + 2026.1 pin
    mullvad-vpn-nix = {
      url = "github:Daaboulex/mullvad-vpn-nix";
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

    # Codex CLI - AI coding assistant (Always up-to-date)
    codex-cli = {
      url = "github:sadjow/codex-cli-nix";
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

    # Linux CoreCycler - Per-core CPU stability tester and PBO CO tuner
    linux-corecycler = {
      url = "github:Daaboulex/linux-corecycler";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # StreamController - Elgato Stream Deck control with CLI and declarative config
    streamcontroller-nix = {
      url = "github:Daaboulex/streamcontroller-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # GoXLR Utility HM module - Declarative mixer configuration
    goxlr-hm-nix = {
      url = "github:Daaboulex/goxlr-hm-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # CoolerControl - Fan/cooling device management (v4.0.1)
    coolercontrol = {
      url = "github:Daaboulex/coolercontrol-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # OpenViking - Agent-native context database for AI agents
    openviking = {
      url = "github:Daaboulex/openviking-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Gemini-CLI - Gemini agent for your terminal
    gemini-cli-nix = {
      url = "github:Daaboulex/gemini-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # LM Studio - Local LLM inference desktop app and server
    lmstudio = {
      url = "github:Daaboulex/lmstudio-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Models CLI - TUI for browsing AI models, benchmarks, and coding agents
    models-nix = {
      url = "github:Daaboulex/models-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # durdraw - Unicode/ANSI/ASCII art editor for the terminal
    durdraw-nix = {
      url = "github:Daaboulex/durdraw-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ripgrep - Fast recursive grep replacement (Level C: integrity + CI + upstream trust)
    ripgrep-nix = {
      url = "github:Daaboulex/ripgrep-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Site — private infrastructure registry (local-only, Syncthing-synced)
    site = {
      url = "git+file:///home/user/Documents/site";
      flake = false;
    };

    # treefmt-nix - Unified code formatting via flake-parts
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # git-hooks.nix - Pre-commit hooks via flake-parts
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Impermanence - Opt-in state management (erase root on every boot)
    impermanence = {
      url = "github:nix-community/impermanence";
    };

    # Disko - Declarative disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NixVirt - Declarative libvirt VM management
    NixVirt = {
      url = "github:AshleyYakeley/NixVirt/v0.6.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # VFIO stealth — VM anti-detection stack (QEMU, OVMF, ACPI, SMBIOS, timing)
    vfio-stealth = {
      url = "github:Daaboulex/vfio-stealth-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Rocksmith 2014 — WineASIO, rs-autoconnect, patch-rocksmith
    rocksmith-nix = {
      url = "github:Daaboulex/rocksmith-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  # ============================================================================
  # Outputs - System configurations and overlays
  # ============================================================================
  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ ./parts/flake-module.nix ];

      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            localSystem.system = system;
            config.allowUnfree = true;
            # Same overlay composition every host uses — keeps checks.*,
            # devShells.*, and nixosConfigurations.* seeing identical pkgs.
            overlays = [ inputs.self.overlays.default ];
          };
        };
    };
}

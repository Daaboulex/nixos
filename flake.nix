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

    # rEFInd — declarative rEFInd bootloader with typed options, security validation
    refind-nix = {
      url = "github:Daaboulex/refind-nix";
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
      url = "github:Daaboulex/eden-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Portmaster - Privacy Application (Local Flake)
    portmaster = {
      url = "github:Daaboulex/portmaster-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Mullvad VPN - declarative daemon + GUI prefs + 2026.1 pin
    mullvad-vpn-nix = {
      url = "github:Daaboulex/mullvad-vpn-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # OCCT - Stability Test & Benchmark (Local Flake)
    occt-nix = {
      url = "github:Daaboulex/OCCT-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # LLM Agents - All AI coding CLIs (claude-code, codex, opencode, crush)
    # numtide/llm-agents.nix — consumed via overlays.shared-nixpkgs: their
    # package tree builds against OUR pkgs (one nixpkgs, deps shared, our
    # overlay fixes apply to their packages), so their nixpkgs input is unused
    # and follows ours. Their binary cache is not wired: it only serves builds
    # of their own pinned rev, which ours will practically never be.
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Mesa-git - Bleeding-edge Mesa from main branch
    mesa-git-nix = {
      url = "github:Daaboulex/mesa-git-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # LSFG-VK - Vulkan Frame Generation (Lossless Scaling)
    lsfg-vk = {
      url = "github:Daaboulex/lsfg-vk-nix";
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

    # Site — private infrastructure registry, its OWN git repo under repos/
    # (git-ignored by this flake, Syncthing-synced, never pushed). Fetched as a
    # separate git repo (not a relative path:) BECAUSE repos/ is git-ignored — a
    # relative path input would require tracking the private secrets in this
    # public repo. The absolute path is valid on every fleet host (all user@
    # /home/user); a host with a different $HOME overrides it via nrb
    # (--override-input site …). CI overrides this to ci/site-stub.
    site = {
      url = "git+file:///home/user/Documents/nix/repos/site";
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
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
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

    # OpenHMD -- Rift CV1 6DoF constellation tracking. The ONLY implementation
    # anywhere (upstream OpenHMD is unmaintained and 3DoF-only; Monado's
    # constellation branch covers WMR/Rift S, not CV1). Daaboulex/OpenHMD is
    # our fork of thaytan/OpenHMD: permanence insurance (survives upstream
    # deletion) and the home for future build fixes; the community reference
    # (Envision's default) stays thaytan's rift-room-config -- sync the fork
    # from it if the author ever resumes. Non-flake src consumed at the point
    # of use by parts/hardware/rift-cv1.nix (no global overlay); update via
    # `nix flake update openhmd-rift`.
    openhmd-rift = {
      url = "github:Daaboulex/OpenHMD/rift-room-config";
      flake = false;
    };

    # nixos-avf — NixOS on Android Virtualization Framework (Pixel 9 Pro builder VM)
    nixos-avf = {
      url = "github:nix-community/nixos-avf/trunk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # scx-git — sched-ext schedulers built from git (Daaboulex fork, packaged with
    # nix-packaging-standard). Wired by direct package reference at the point of use
    # (services.scx.package in tuning/performance.nix), NOT via the global overlay —
    # explicit and local, no fleet-wide pkgs mutation.
    scx-git = {
      url = "github:Daaboulex/scx-git-nix";
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
        { system, ... }:
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

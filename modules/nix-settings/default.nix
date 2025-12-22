{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.system.nix.enable = lib.mkEnableOption "Nix daemon configuration and settings";

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf config.myModules.system.nix.enable {
    # Nix daemon settings
    nix.settings = {
      # Enable experimental features
      experimental-features = [ "nix-command" "flakes" ];

      # Automatic store optimization
      auto-optimise-store = true;

      # Keep build outputs for faster rebuilds
      keep-outputs = true;
      keep-derivations = true;

      # Build performance
      max-jobs = "auto";
      cores = 0;  # Use all available cores per job

      # Download performance (12 GiB buffer)
      download-buffer-size = 12884901888;

      # Security - enable sandboxed builds
      sandbox = true;

      # Binary caches (substituters)
      substituters = [
        "https://cache.nixos.org"           # Official NixOS cache (fastest)
        "https://chaotic-nyx.cachix.org"    # CachyOS kernels and packages
        "https://nix-community.cachix.org"  # Community packages
      ];

      # Trusted public keys for binary caches
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nixos-wsl:z3KM2d7MwxRjB+kRQeSWzqeflwH/20xzefwjIET9f18="  # WSL build machine
      ];

      # Fallback to building locally if substituters fail
      fallback = true;

      # Sign packages automatically (for build machines)
      # This allows other machines to trust packages built here
      secret-key-files = lib.mkIf (builtins.pathExists "/etc/nix/signing-key.sec") [
        "/etc/nix/signing-key.sec"
      ];
    };

    # Automatic garbage collection
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    # Enable nix-ld for running non-NixOS binaries
    programs.nix-ld.enable = true;

    # Useful Nix tools
    environment.systemPackages = with pkgs; [
      nix-output-monitor  # Better build output (nom)
      nix-tree            # Explore dependency trees
      nvd                 # Nix version diff - shows what changed between generations
    ];
  };
}
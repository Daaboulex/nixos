{ inputs, ... }: {
  flake.nixosModules.system-nix = { config, lib, pkgs, ... }: {
    options.myModules.system.nix = {
      enable = lib.mkEnableOption "Nix daemon configuration and settings";
    };

    config = lib.mkIf config.myModules.system.nix.enable {
      nix.settings = {
        experimental-features = [ "nix-command" "flakes" ];
        auto-optimise-store = true;
        keep-outputs = true;
        keep-derivations = true;
        max-jobs = lib.mkDefault "auto";
        cores = lib.mkDefault 0;
        # Max NAR size buffered in RAM during downloads. Larger NARs fall back to
        # disk streaming (slower but safe). Keep conservative for low-RAM systems.
        download-buffer-size = lib.mkDefault (2 * 1024 * 1024 * 1024);  # 2 GiB
        sandbox = true;
        substituters = [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "nixos-wsl:z3KM2d7MwxRjB+kRQeSWzqeflwH/20xzefwjIET9f18="
        ];
        fallback = true;
        secret-key-files = lib.mkIf (builtins.pathExists "/etc/nix/signing-key.sec") [
          "/etc/nix/signing-key.sec"
        ];
      };

      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };

      programs.nix-ld.enable = true;

      environment.systemPackages = with pkgs; [
        nix-output-monitor
        nix-tree
        nvd
      ];
    };
  };
}

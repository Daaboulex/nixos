# nix — Nix daemon configuration, flakes, substituters, and garbage collection.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.nix.nix;
    in
    {
      _class = "nixos";
      options.myModules.nix.nix = {
        enable = lib.mkEnableOption "Nix daemon configuration and settings";
        githubTokenSource = lib.mkOption {
          type = lib.types.enum [
            "agenix"
            "gh-cli"
            "none"
          ];
          default = "gh-cli";
          description = ''
            Where nix-daemon gets the GitHub API token (for rate-limited
            flake fetches).
              • `agenix` — decrypt from secrets/github-token.age at boot
                (declarative; requires `agenix -e secrets/github-token.age`
                with content `access-tokens = github.com=ghp_...`).
              • `gh-cli` — activation script reads `gh auth token` into
                /etc/nix/github-token. Opportunistic (no-op if gh not
                configured for root).
              • `none` — no GitHub token configured. Flake updates hit
                unauthenticated rate limits.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        nix.settings = {
          experimental-features = [
            "nix-command"
            "flakes"
            "cgroups"
          ];
          auto-optimise-store = true;
          keep-outputs = true;
          keep-derivations = true;
          max-jobs = lib.mkDefault "auto";
          cores = lib.mkDefault 0;
          # Max NAR size buffered in RAM during downloads. Larger NARs fall back to
          # disk streaming (slower but safe). Keep conservative for low-RAM systems.
          download-buffer-size = lib.mkDefault (2 * 1024 * 1024 * 1024); # 2 GiB
          sandbox = true;
          # Isolate each build in its own cgroup for accurate memory tracking
          # and preventing one build from OOM-killing another.
          use-cgroups = true;
          connect-timeout = lib.mkDefault 5;
          stalled-download-timeout = lib.mkDefault 300;
          http-connections = lib.mkDefault 25;
          log-lines = 50;
          trusted-users = [
            "root"
            config.myModules.primaryUser
          ];
          substituters = [
            "https://cache.nixos.org"
            "https://nix-community.cachix.org"
          ];
          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          ];
          fallback = true;
          secret-key-files = lib.mkIf (builtins.pathExists "/etc/nix/signing-key.sec") [
            "/etc/nix/signing-key.sec"
          ];
        };

        # GitHub API token for rate-limited flake fetches. Three sources
        # (see option doc above). `!include` silently skips if missing,
        # so any of them failing is safe.
        age.secrets.github-token = lib.mkIf (cfg.githubTokenSource == "agenix") {
          file = config.myModules.security.agenix.secretsRoot + "/github-token.age";
          mode = "0400";
          owner = "root";
        };

        nix.extraOptions = lib.mkMerge [
          (lib.mkIf (cfg.githubTokenSource == "agenix") ''
            !include ${config.age.secrets.github-token.path}
          '')
          (lib.mkIf (cfg.githubTokenSource == "gh-cli") ''
            !include /etc/nix/github-token
          '')
        ];

        # Legacy gh-cli path: populate /etc/nix/github-token from gh CLI
        # at activation time. Only runs when source = "gh-cli".
        system.activationScripts.nix-github-token = lib.mkIf (cfg.githubTokenSource == "gh-cli") {
          text = ''
            if command -v gh >/dev/null 2>&1; then
              token=$(gh auth token 2>/dev/null || true)
              if [ -n "$token" ]; then
                echo "access-tokens = github.com=$token" > /etc/nix/github-token
                chmod 600 /etc/nix/github-token
              fi
            fi
          '';
        };

        nix.gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };

      };
    };
in
{
  flake.modules.nixos.nix-nix = mod;

}

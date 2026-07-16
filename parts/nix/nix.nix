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

      # Agenix integration is in the host flake-modules that import both
      # nix-nix and security-agenix. Moved there to avoid coupling.

      options.myModules.nix.nix = {
        enable = lib.mkEnableOption "Nix daemon configuration and settings";
        githubTokenSource = lib.mkOption {
          type = lib.types.enum [
            "gh-cli"
            "none"
          ];
          default = "gh-cli";
          description = ''
            Where nix-daemon gets the GitHub API token (for rate-limited
            flake fetches).
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
          # Move Nix's well-known symlinks (~/.nix-profile, ~/.nix-defexpr,
          # ~/.nix-channels) under $XDG_STATE_HOME so they stop cluttering $HOME.
          # Safe on flakes+NixOS: home-manager derives its profile path from this
          # setting, and the real per-user profile already lives under state.
          use-xdg-base-directories = true;
          max-jobs = lib.mkDefault "auto";
          cores = lib.mkDefault 0;
          # Max NAR size buffered in RAM during downloads. Larger NARs fall back to
          # disk streaming (slower but safe). Keep conservative for low-RAM systems.
          download-buffer-size = lib.mkDefault (2 * 1024 * 1024 * 1024); # 2 GiB
          sandbox = true;
          # Fsync file data before registering a path valid. Without it an
          # unclean shutdown leaves 0-byte store files the nix DB trusts
          # (bit the macbook: truncated fetcher-cache JSON broke flake update).
          fsync-store-paths = true;
          # Emergency GC during builds — prevents disk-full mid-build.
          min-free = lib.mkDefault (1 * 1024 * 1024 * 1024); # 1 GiB trigger
          max-free = lib.mkDefault (5 * 1024 * 1024 * 1024); # 5 GiB target
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
          # Sign every local build so inter-host copies verify and
          # `nix store verify` trusts local paths. The key is generated
          # on-host at activation (nix-signing-key below) -- a pathExists
          # guard here would be dead code: pure flake eval always returns
          # false for absolute host paths.
          secret-key-files = [ "/etc/nix/signing-key.sec" ];
        };

        nix.extraOptions = lib.mkIf (cfg.githubTokenSource == "gh-cli") ''
          !include /etc/nix/github-token
        '';

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

        # Per-host store signing keypair. Generated once, on-host, at
        # activation (before services restart, so the daemon always finds
        # the file secret-key-files points at). The PUBLIC key is written
        # next to it for pinning in other hosts' trusted-public-keys.
        system.activationScripts.nix-signing-key.text = ''
          if [ ! -e /etc/nix/signing-key.sec ]; then
            mkdir -p /etc/nix
            (
              umask 077
              ${config.nix.package}/bin/nix key generate-secret \
                --key-name "${config.networking.hostName}-1" > /etc/nix/signing-key.sec
            )
          fi
          if [ ! -e /etc/nix/signing-key.pub ]; then
            ${config.nix.package}/bin/nix key convert-secret-to-public \
              < /etc/nix/signing-key.sec > /etc/nix/signing-key.pub
            chmod 644 /etc/nix/signing-key.pub
          fi
          # secret-key-files points here unconditionally: a missing or empty
          # key would fail every subsequent build, so fail the activation
          # loudly at the source instead.
          if [ ! -s /etc/nix/signing-key.sec ]; then
            echo "nix-signing-key: FAILED to generate /etc/nix/signing-key.sec (empty or absent); aborting activation -- the daemon's secret-key-files would break every build." >&2
            exit 1
          fi
        '';

        # GC is owned by nh (nix.gc.automatic stays off; NixOS warns if both run).
        # This is the single source of truth for the SAFE clean policy -- the weekly
        # timer here and bare `gc` both run this same nh-clean service. (`gc --deep`
        # is a separate opt-in prune that also collects gcroots; see the zsh module.)
        nix.gc.automatic = false;

        programs.nh = {
          enable = true;
          clean = {
            enable = true;
            dates = "weekly";
            # nh 4.3.2 deletes direnv/devShell gcroots by default; --no-gcroots
            # skips the entire gcroot pass so no project (direnv, devenv, or
            # nix-shell) ever rebuilds after a clean. Cost: stray `result`
            # symlinks aren't pruned -- an accepted trade for never losing a shell.
            extraArgs = "--keep 5 --keep-since 7d --no-gcroots";
          };
        };

      };
    };
in
{
  flake.modules.nixos.nix-nix = mod;

}

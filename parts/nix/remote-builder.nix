# remote-builder — offload nix builds from laptop → desktop (or similar).
#
# Two complementary options:
#
#   myModules.nix.remoteBuilder.client — this host uses a remote for builds
#   myModules.nix.remoteBuilder.server — this host serves builds to others
#
# Typical: macbook-pro-9-2 client, ryzen-9950x3d server.
#
# One-time setup (bootstrap SSH key outside nix):
#   sudo ssh-keygen -f /root/.ssh/remotebuild -N ""
#   sudo cat /root/.ssh/remotebuild.pub   # paste into server host config
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
      cfg = config.myModules.nix.remoteBuilder;
    in
    {
      _class = "nixos";
      options.myModules.nix.remoteBuilder = {
        client = {
          enable = lib.mkEnableOption "offload builds to a remote nix-daemon over SSH";

          hostName = lib.mkOption {
            type = lib.types.str;
            example = "ryzen-9950x3d";
            description = "Remote builder hostname (SSH-reachable).";
          };

          sshUser = lib.mkOption {
            type = lib.types.str;
            default = "remotebuild";
            description = "SSH user on the remote builder. Must be in trusted-users there.";
          };

          sshKey = lib.mkOption {
            type = lib.types.str;
            default = "/root/.ssh/remotebuild";
            description = "Path to SSH private key on THIS host for remote builder auth.";
          };

          system = lib.mkOption {
            type = lib.types.str;
            default = "x86_64-linux";
            description = "System architecture the remote can build for.";
          };

          maxJobs = lib.mkOption {
            type = lib.types.ints.positive;
            default = 8;
            description = ''
              Parallel derivations the remote can build concurrently.
              Rule of thumb: size to remote's logical cores (physical ×
              SMT). Each build internally uses `nix.settings.cores`
              worker threads, so the product must fit hardware.

              Examples:
                • 9950X3D (16C/32T): `maxJobs = 32` with `cores = 1`
                  → 32 concurrent compiles, each single-threaded. Best
                  for many-small-derivations workloads.
                • 9950X3D balanced: `maxJobs = 16` with `cores = 4`
                  → 16 builds × 4 threads = 64 compile-threads. Best
                  for kernel/chromium/LibreOffice.
                • Conservative default (8): works on any modern quad.

              `nix.buildMachines` takes an integer here — there is no
              "auto" for remotes (the remote's own `nix.settings.max-
              jobs = "auto"` governs whether it accepts the submission).
            '';
          };

          speedFactor = lib.mkOption {
            type = lib.types.ints.positive;
            default = 10;
            description = ''
              Relative speed vs local. Higher = nix prefers this remote
              when the local machine and remote both support a given
              build. 10× for ryzen-vs-MBP (roughly: Zen 5 16C/32T
              ~20× the compile-wall-clock of Ivy Bridge 2C/4T on GCC).
            '';
          };

          supportedFeatures = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "nixos-test"
              "benchmark"
              "big-parallel"
              "kvm"
            ];
            description = "Build features the remote supports (needed for compilers + VM tests).";
          };

          hostPublicKey = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5… root@hostname";
            description = ''
              Remote builder's SSH host public key — get it from the
              remote with `cat /etc/ssh/ssh_host_ed25519_key.pub`.
              When set, the client pre-trusts the remote in its root
              known_hosts so nix-daemon's non-interactive SSH never
              hits a trust-on-first-use prompt. If left null, the
              client falls back to StrictHostKeyChecking=accept-new
              semantics (first connection pins the key).
            '';
          };

          extraHostNames = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [
              "my-builder"
              "192.168.1.100"
            ];
            description = ''
              Additional hostnames/IPs the remote answers to. Added to
              the SSH known_hosts entry alongside `hostName`, so the
              same host public key is trusted no matter which name was
              used to connect (hostname + .local + LAN IP, for example).
            '';
          };

          staticIp = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "192.168.1.100";
            description = ''
              LAN IP for the remote. When set, adds a `networking.hosts`
              entry so `hostName` resolves even if mDNS breaks. Leave
              null to rely entirely on mDNS/DNS resolution.
            '';
          };
        };

        server = {
          enable = lib.mkEnableOption "accept remote build requests (adds remotebuild user + trusted)";

          authorizedKeys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = ''
              SSH public keys of clients allowed to submit builds.
              Paste output of `sudo cat /root/.ssh/remotebuild.pub` from each client here.
            '';
          };
        };
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.client.enable {
          nix.distributedBuilds = true;
          nix.settings.builders-use-substitutes = true;
          # Local builds enabled as fallback when remote is unreachable.
          # The build hook tries remote FIRST (nix architecture guarantee:
          # hook is consulted before local slots). With remote up + high
          # speedFactor, builds go to remote naturally. With remote down,
          # hook emits `# decline` and daemon falls back to local.
          # Previous max-jobs=0 forced remote-only but broke offline use
          # (hook emits `# postpone` → hangs indefinitely). Removed 2026-05-05.
          # See: build-remote.cc canBuildLocally, NixOS/nix#7101.
          nix.buildMachines = [
            {
              inherit (cfg.client)
                hostName
                sshUser
                sshKey
                system
                maxJobs
                speedFactor
                supportedFeatures
                ;
              protocol = "ssh-ng";
            }
          ];

          # Pre-trust remote host key so nix-daemon's non-interactive
          # SSH never prompts. Only applied when hostPublicKey is set.
          programs.ssh.knownHosts = lib.mkIf (cfg.client.hostPublicKey != null) {
            "remote-builder" = {
              hostNames = [ cfg.client.hostName ] ++ cfg.client.extraHostNames;
              publicKey = cfg.client.hostPublicKey;
            };
          };

          # LAN IP fallback in /etc/hosts when staticIp is set — keeps
          # the builder reachable if mDNS/DNS breaks. The hostName (and
          # all extraHostNames except IPs) resolve to the pinned IP.
          networking.hosts = lib.mkIf (cfg.client.staticIp != null) {
            ${cfg.client.staticIp} = lib.filter (
              n: !(lib.hasInfix "." n) || !(builtins.match "[0-9.]+" n != null)
            ) ([ cfg.client.hostName ] ++ cfg.client.extraHostNames);
          };

          # Note: we deliberately don't warn on `!pathExists sshKey` here.
          # `builtins.pathExists` checks the EVALUATOR's filesystem, not
          # the target host's — which means warm-building mac's config
          # from ryzen (where /root/.ssh/remotebuild doesn't exist) fires
          # a false-positive warning every nrb. The key's existence is
          # verified at connection time by SSH anyway; missing key =
          # clear connection error, no need for a preflight alarm.
        })

        (lib.mkIf cfg.server.enable {
          # Allow remotebuild user through sshd's AllowUsers gate.
          # Without this, ssh.nix's AllowUsers = [root primaryUser] blocks
          # the remotebuild user and all remote builds fail silently with
          # "failed to start SSH connection".
          services.openssh.settings.AllowUsers = [ "remotebuild" ];

          users.users.remotebuild = {
            isSystemUser = true;
            group = "remotebuild";
            useDefaultShell = true;
            openssh.authorizedKeys.keys = cfg.server.authorizedKeys;
          };
          users.groups.remotebuild = { };
          nix.settings.trusted-users = [ "remotebuild" ];
          # Tune nix-daemon on the server for heavy parallel builds
          nix.settings = {
            max-jobs = "auto";
            cores = 0; # "use all" — overrides per-host macbook's cores=2
          };
        })
      ];
    };
in
{
  flake.modules.nixos.nix-remote-builder = mod;
}

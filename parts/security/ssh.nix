# ssh — OpenSSH server with key-only auth and hardened crypto defaults.
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
      cfg = config.myModules.security.ssh;
    in
    {
      _class = "nixos";
      options.myModules.security.ssh = {
        enable = lib.mkEnableOption "Secure SSH server configuration";
        trustedKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "List of trusted SSH public keys";
        };
        fail2banIgnoreIPs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "127.0.0.1/8"
            "::1/128"
          ];
          description = "Loopback baseline never to ban. The module owns this default; hosts add LAN/VPN ranges via extraIgnoreSubnets rather than restating it.";
        };
        extraIgnoreSubnets = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Host LAN/VPN subnets appended to the fail2ban ignore list (e.g. [ site.network.subnet ]) -- separate so a host adds its subnet without re-listing the loopback baseline.";
        };
      };

      config = lib.mkIf cfg.enable {
        # Host identity lives OUTSIDE /etc: /etc must carry no load-bearing
        # runtime state (an /etc overlay hides anything not managed by
        # environment.etc, and a hidden host key silently regenerates --
        # agenix identity, registry pins, and remote-builder trust all
        # break). ed25519 only: every pinned identity in the site registry
        # is ed25519, and the hardened crypto below is modern-only anyway.
        # The activation script migrates existing keys: it runs before any
        # service restarts (switch) and before systemd starts services
        # (boot), so sshd can never observe an empty /var/lib/ssh on a host
        # that already has an identity and regenerate one. Copy-if-absent:
        # never overwrites. MINIMIZE-DEBT: drop the migration block once
        # every host has rebuilt past the relocation (check: ls /var/lib/ssh).
        services.openssh.hostKeys = [
          {
            path = "/var/lib/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
        system.activationScripts.ssh-hostkey-relocation.text = ''
          mkdir -p /var/lib/ssh
          chmod 755 /var/lib/ssh
          if [ ! -e /var/lib/ssh/ssh_host_ed25519_key ] && [ -e /etc/ssh/ssh_host_ed25519_key ]; then
            cp -a /etc/ssh/ssh_host_ed25519_key /var/lib/ssh/ssh_host_ed25519_key
            cp -a /etc/ssh/ssh_host_ed25519_key.pub /var/lib/ssh/ssh_host_ed25519_key.pub
            chmod 600 /var/lib/ssh/ssh_host_ed25519_key
            chmod 644 /var/lib/ssh/ssh_host_ed25519_key.pub
          fi
          # Fail the activation loudly rather than let sshd regenerate a
          # fresh identity over a half-migrated directory.
          if [ ! -e /var/lib/ssh/ssh_host_ed25519_key ] && [ -e /etc/ssh/ssh_host_ed25519_key ]; then
            echo "ssh-hostkey-relocation: FAILED to copy the host key to /var/lib/ssh; aborting activation so sshd cannot regenerate the identity. Original key untouched at /etc/ssh." >&2
            exit 1
          fi
        '';

        services.openssh = {
          enable = true;
          extraConfig = "AuthorizedKeysFile %h/.ssh/authorized_keys /etc/ssh/authorized_keys.d/%u";
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            ChallengeResponseAuthentication = false;
            PermitEmptyPasswords = false;
            PermitRootLogin = "no";
            AllowUsers = [
              config.myModules.primaryUser
            ];
            MaxAuthTries = 3;
            MaxSessions = 10;
            Ciphers = [
              "chacha20-poly1305@openssh.com"
              "aes256-gcm@openssh.com"
              "aes128-gcm@openssh.com"
            ];
            KexAlgorithms = [
              "mlkem768x25519-sha256" # Post-quantum hybrid (ML-KEM + X25519) — silences OpenSSH 10+ warning
              "curve25519-sha256"
              "curve25519-sha256@libssh.org"
              "diffie-hellman-group16-sha512"
              "diffie-hellman-group18-sha512"
            ];
            Macs = [
              "hmac-sha2-512-etm@openssh.com"
              "hmac-sha2-256-etm@openssh.com"
            ];
            ClientAliveInterval = 300;
            ClientAliveCountMax = 2;
            X11Forwarding = false;
            AllowTcpForwarding = "no";
            AllowStreamLocalForwarding = "no";
            AllowAgentForwarding = false;
            GatewayPorts = "no";
          };
        };

        users.users.${config.myModules.primaryUser}.openssh.authorizedKeys.keys = cfg.trustedKeys;
        networking.firewall.allowedTCPPorts = [ 22 ];

        services.fail2ban = {
          enable = true;
          maxretry = 3;
          ignoreIP = cfg.fail2banIgnoreIPs ++ cfg.extraIgnoreSubnets;
          jails.sshd.settings = {
            enabled = true;
            port = "ssh";
            filter = "sshd";
            maxretry = 3;
            findtime = 600;
            bantime = 3600;
          };
        };
      };
    };
in
{
  flake.modules.nixos.security-ssh = mod;

}

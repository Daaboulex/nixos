{ inputs, ... }: {
  flake.nixosModules.system-ssh = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.security.ssh;
    in {
      options.myModules.security.ssh = {
        enable = lib.mkEnableOption "Secure SSH server configuration";
        trustedKeys = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; description = "List of trusted SSH public keys"; };
      };

      config = lib.mkIf cfg.enable {
        services.openssh = {
          enable = true;
          extraConfig = "AuthorizedKeysFile %h/.ssh/authorized_keys";
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            ChallengeResponseAuthentication = false;
            PermitEmptyPasswords = false;
            PermitRootLogin = "prohibit-password";
            AllowUsers = [ config.myModules.primaryUser ];
            MaxAuthTries = 3;
            MaxSessions = 10;
            Ciphers = [ "chacha20-poly1305@openssh.com" "aes256-gcm@openssh.com" "aes128-gcm@openssh.com" ];
            KexAlgorithms = [ "curve25519-sha256" "curve25519-sha256@libssh.org" "diffie-hellman-group16-sha512" "diffie-hellman-group18-sha512" ];
            Macs = [ "hmac-sha2-512-etm@openssh.com" "hmac-sha2-256-etm@openssh.com" ];
            ClientAliveInterval = 300;
            ClientAliveCountMax = 2;
            X11Forwarding = false;
            AllowTcpForwarding = "yes";
            AllowStreamLocalForwarding = "no";
            AllowAgentForwarding = false;
            GatewayPorts = "no";
          };
        };

        users.users.user.openssh.authorizedKeys.keys = cfg.trustedKeys;
        networking.firewall.allowedTCPPorts = [ 22 ];

        services.fail2ban = {
          enable = true;
          maxretry = 3;
          ignoreIP = [ "127.0.0.1/8" "192.168.0.0/16" ];
          jails.sshd.settings = { enabled = true; port = "ssh"; filter = "sshd"; maxretry = 3; findtime = 600; bantime = 3600; };
        };
      };
    };
}

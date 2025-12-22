{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.security.ssh = {
    enable = lib.mkEnableOption "Secure SSH server configuration";

    trustedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of trusted SSH public keys for passwordless authentication";
      example = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExample... user@desktop"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExample... user@laptop"
      ];
    };
  };

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf config.myModules.security.ssh.enable {
    # OpenSSH server configuration
    services.openssh = {
      enable = true;

      # Specify authorized keys file location
      extraConfig = ''
        AuthorizedKeysFile %h/.ssh/authorized_keys
      '';

      settings = {
        # ======================================================================
        # Authentication Settings
        # ======================================================================
        # Disable password authentication - require SSH keys only
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        ChallengeResponseAuthentication = false;
        PermitEmptyPasswords = false;

        # Root can only login with SSH keys (no password)
        PermitRootLogin = "prohibit-password";

        # Only allow specific users to connect
        AllowUsers = [ "user" ];

        # Limit authentication attempts
        MaxAuthTries = 3;
        MaxSessions = 10;

        # ======================================================================
        # Cryptographic Settings
        # ======================================================================
        # Use only strong, modern ciphers
        Ciphers = [
          "chacha20-poly1305@openssh.com"
          "aes256-gcm@openssh.com"
          "aes128-gcm@openssh.com"
        ];

        # Use only strong key exchange algorithms
        KexAlgorithms = [
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
          "diffie-hellman-group16-sha512"
          "diffie-hellman-group18-sha512"
        ];

        # Use only strong MAC algorithms
        Macs = [
          "hmac-sha2-512-etm@openssh.com"
          "hmac-sha2-256-etm@openssh.com"
        ];

        # ======================================================================
        # Connection Settings
        # ======================================================================
        # Keep-alive settings (disconnect idle clients after 10 minutes)
        ClientAliveInterval = 300;  # 5 minutes
        ClientAliveCountMax = 2;    # 2 missed keep-alives = 10 minutes total

        # ======================================================================
        # Forwarding Settings
        # ======================================================================
        # Disable X11 forwarding for security
        X11Forwarding = false;

        # Allow TCP forwarding (needed for remote builds and port forwarding)
        AllowTcpForwarding = "yes";

        # Disable other forwarding types
        AllowStreamLocalForwarding = "no";
        AllowAgentForwarding = false;
        GatewayPorts = "no";
      };
    };

    # Add trusted SSH keys to the primary user account
    users.users.user.openssh.authorizedKeys.keys = config.myModules.security.ssh.trustedKeys;

    # Open SSH port in firewall
    networking.firewall.allowedTCPPorts = [ 22 ];

    # Optional: Restrict SSH to local network only
    # Uncomment and adjust the network range as needed
    # networking.firewall.extraCommands = ''
    #   # Allow SSH only from local network (192.168.1.0/24)
    #   iptables -I nixos-fw -p tcp --dport 22 -s 192.168.1.0/24 -j nixos-fw-accept
    #
    #   # Drop all other SSH attempts
    #   iptables -A nixos-fw -p tcp --dport 22 -j nixos-fw-log-refuse
    # '';

    # Fail2ban for brute-force protection
    services.fail2ban = {
      enable = true;
      maxretry = 3;

      # Don't ban local network or localhost
      ignoreIP = [
        "127.0.0.1/8"
        "192.168.0.0/16"  # Adjust to your local network range
      ];

      # SSH jail configuration
      jails.sshd.settings = {
        enabled = true;
        port = "ssh";
        filter = "sshd";
        maxretry = 3;       # Ban after 3 failed attempts
        findtime = 600;     # Within 10 minutes
        bantime = 3600;     # Ban for 1 hour
      };
    };
  };
}

# ==============================================================================
# SETUP INSTRUCTIONS
# ==============================================================================
#
# 1. Generate an SSH key on your client machine (if you don't have one):
#    ssh-keygen -t ed25519 -C "user@client-machine"
#
# 2. Get your public key:
#    cat ~/.ssh/id_ed25519.pub
#
# 3. Add the public key to your host configuration:
#    myModules.security.ssh = {
#      enable = true;
#      trustedKeys = [
#        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... user@client-machine"
#      ];
#    };
#
# 4. Rebuild your system:
#    sudo nixos-rebuild switch --flake .#hostname
#
# 5. Test SSH connection from client:
#    ssh user@hostname
#
# ==============================================================================

# pixel-9-pro — NixOS host config for AVF Linux VM on Pixel 9 Pro (Tensor G4, 4 GB VM RAM).
{
  config,
  pkgs,
  inputs,
  lib,
  site,
  ...
}:
{
  # ============================================================================
  # MyModules Configuration
  # ============================================================================
  myModules = {

    # --------------------------------------------------------------------------
    # Nix
    # --------------------------------------------------------------------------
    nix.nix.enable = true;
    nix.remoteBuilder = {
      client.enable = false;
      server = {
        enable = true;
        inherit (site.hosts.pixel-9-pro.ssh.remoteBuilder) authorizedKeys;
      };
    };

    # --------------------------------------------------------------------------
    # Users
    # --------------------------------------------------------------------------
    users.enable = true;

    # --------------------------------------------------------------------------
    # Security
    # --------------------------------------------------------------------------
    services.avahi.enable = true;

    security.ssh.enable = true;
  };

  # ============================================================================
  # AVF VM overrides
  # ============================================================================

  # Default user — matches nixos-avf convention
  avf.defaultUser = "droid";

  # SSH — key-only, hardened, port 2222 (AVF blocks < 1024)
  services.openssh = {
    enable = true;
    ports = [ 2222 ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  users.users.droid.openssh.authorizedKeys.keys = site.hosts.pixel-9-pro.ssh.authorizedKeys;

  # Nix daemon — trusted user for remote builder, lean GC
  nix.settings = {
    trusted-users = [
      "root"
      "droid"
    ];
    min-free = 1073741824; # 1 GB
    max-free = 3221225472; # 3 GB
    auto-optimise-store = true;
    max-jobs = "auto";
    cores = 0;
  };

  # Swap — 4 GB file on disk to supplement 4 GB RAM + 1 GB zram.
  # Prevents OOM during nixos-rebuild on large flakes.
  # Total effective memory: 4 GB RAM + 1 GB zram + 4 GB disk swap = ~9 GB.
  swapDevices = [
    {
      device = "/var/swapfile";
      size = 4096;
    }
  ];

  # Firewall — allow SSH
  networking.firewall.allowedTCPPorts = [ 2222 ];

  system.stateVersion = "25.11";
}

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

    # AVF convention — gates ssh AllowUsers + users.nix account creation
    primaryUser = "droid";

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

    security.ssh = {
      enable = true;
      trustedKeys = site.hosts.pixel-9-pro.ssh.authorizedKeys;
    };

    services.syncthing = {
      enable = true;
      devices.ryzen-9950x3d = {
        id = site.hosts.ryzen-9950x3d.syncthing.deviceId;
        addresses = [
          "tcp://ryzen-9950x3d.local:22000"
          "dynamic"
        ];
      };
      devices.macbook-pro-9-2 = {
        id = site.hosts.macbook-pro-9-2.syncthing.deviceId;
        addresses = [
          "tcp://macbook-pro-9-2.local:22000"
          "dynamic"
        ];
      };
      folders = {
        documents = {
          path = "/home/droid/Documents";
          devices = [
            "ryzen-9950x3d"
            "macbook-pro-9-2"
          ];
        };
        ai-context = {
          path = "/home/droid/.ai-context";
          devices = [
            "ryzen-9950x3d"
            "macbook-pro-9-2"
          ];
          ignorePerms = true;
          versioningMaxAge = "1209600";
        };
      };
    };
  };

  # ============================================================================
  # AVF VM overrides
  # ============================================================================

  avf.defaultUser = "droid";
  avf.enableGraphics = false;
  networking.hostName = "pixel-9-pro";

  # x86_64 emulation via QEMU binfmt_misc (no KVM — pure TCG, ~10x slower
  # than native). Pixel's real value is as a native aarch64 builder;
  # x86_64 emulation kept for emergency cross-arch builds only.
  boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
  environment.variables.QEMU_CPU = "max";

  # SSH port — AVF blocks < 1024. ssh.nix handles all other settings.
  services.openssh.ports = [ 2222 ];

  # Nix daemon — tuned for 4 GB VM
  nix.settings = {
    download-buffer-size = 512 * 1024 * 1024; # 512 MiB (shared default 2 GiB — too large for 4 GB)
    max-substitution-jobs = 16; # saturate downloads from cache
  };

  # zram — override AVF default (ram/4) to ram/2 for better effective memory.
  # 2 GB compressed at ~3:1 ratio → ~6 GB effective swap in RAM.
  services.zram-generator.settings."zram0".zram-size = lib.mkForce "ram / 2";

  # Prefer zram (fast, compressed RAM) over evicting file caches.
  # Values >100 are valid on kernels ≥5.8 with zram; 180 is recommended.
  boot.kernel.sysctl."vm.swappiness" = 180;

  # Disk swap — 4 GB file as fallback after zram fills.
  # Total effective: 4 GB RAM + 2 GB zram (~6 GB at 3:1) + 4 GB disk = ~14 GB.
  swapDevices = [
    {
      device = "/var/swapfile";
      size = 4096;
    }
  ];

  # Firewall — SSH on 2222 only
  networking.firewall.allowedTCPPorts = [ 2222 ];

  # Override ssh.nix's fail2ban — 4 GB AVF VM can't spare the RAM
  services.fail2ban.enable = lib.mkForce false;

  system.stateVersion = "25.11";
}

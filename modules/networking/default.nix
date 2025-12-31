{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.hardware.networking.enable = lib.mkEnableOption "Network configuration";

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf config.myModules.hardware.networking.enable {
    # ==========================================================================
    # Network Manager
    # ==========================================================================
    # Enable NetworkManager for easy network configuration
    networking.networkmanager.enable = lib.mkDefault true;

    # ==========================================================================
    # Firewall Configuration
    # ==========================================================================
    networking.firewall = {
      enable = true;

      # NX-Save-Sync port (for Switch save file sync)
      allowedTCPPorts = [ 8080 ];

      # KDE Connect port ranges (for file sharing, notifications, etc.)
      allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
      allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];
    };

    # ==========================================================================
    # DNS Configuration
    # ==========================================================================
    # Using privacy-respecting DNS servers with low latency for Germany
    networking.nameservers = [
      # ----------------------------------------------------------------------
      # DNSForge (Germany) - Primary DNS
      # ----------------------------------------------------------------------
      # Privacy-respecting DNS provider based in Germany
      # Low latency for European users
      "176.9.93.198"                # DNSForge primary (IPv4)
      "176.9.1.117"                 # DNSForge secondary (IPv4)
      "2a01:4f8:151:34aa::198"      # DNSForge primary (IPv6)
      "2a01:4f8:141:316d::117"      # DNSForge secondary (IPv6)

      # ----------------------------------------------------------------------
      # Quad9 (EU anycast) - Fallback DNS
      # ----------------------------------------------------------------------
      # Provides malware and phishing protection
      # Anycast network for reliability
      "9.9.9.9"                     # Quad9 fallback (IPv4)
      "149.112.112.112"             # Quad9 fallback (IPv4)
      "2620:fe::fe"                 # Quad9 fallback (IPv6)
      "2620:fe::9"                  # Quad9 fallback (IPv6)
    ];
  };
}
# networking — NetworkManager, firewall, and hostname configuration.
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
      cfg = config.myModules.hardware.networking;
    in
    {
      _class = "nixos";
      options.myModules.hardware.networking = {
        enable = lib.mkEnableOption "Networking configuration";
        openPorts = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = [ ];
          description = "List of TCP ports to open";
        };
        openPortRanges = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                from = lib.mkOption {
                  type = lib.types.port;
                  description = "Start of port range (inclusive)";
                };
                to = lib.mkOption {
                  type = lib.types.port;
                  description = "End of port range (inclusive)";
                };
              };
            }
          );
          default = [ ];
          description = "Port ranges to open on TCP and UDP (e.g. `[{ from = 1000; to = 2000; }]`)";
        };
        nameservers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            # Mullvad adblock DoT resolver — IP + SNI hostname pair so
            # systemd-resolved can validate the cert while doing DoT on :853.
            # Works even when Mullvad VPN is off (still fully DoT-encrypted).
            "194.242.2.3#dns.mullvad.net"
            "2a07:e340::3#dns.mullvad.net"
          ];
          description = ''
            DNS nameservers. Default is Mullvad's adblock DoT resolver with
            SNI hint so systemd-resolved validates the TLS certificate.
            Override per-host if you want a different upstream.
          '';
        };
        dnsOverTls = lib.mkOption {
          type = lib.types.enum [
            "true"
            "opportunistic"
            "false"
          ];
          default = "true";
          description = ''
            systemd-resolved DNSOverTLS policy. "true" requires DoT and refuses
            plaintext fallback (recommended). "opportunistic" tries DoT first,
            falls back to plaintext on failure (weaker guarantee but more
            robust on captive portals). "false" disables DoT entirely.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        networking = {
          networkmanager.enable = true;
          firewall = {
            enable = true;
            allowedTCPPorts = cfg.openPorts;
            allowedTCPPortRanges = cfg.openPortRanges;
            allowedUDPPortRanges = cfg.openPortRanges;
          };
          inherit (cfg) nameservers;
        };

        # systemd-resolved with DoT closes the app-DNS plaintext leak that
        # existed with the old Quad9-over-UDP53 default. Queries to the stub
        # resolver (127.0.0.53) now go out as DoT on :853, whether Mullvad
        # VPN is connected or not. DNSSEC left at its default (off) — Mullvad
        # doesn't sign their adblock view so enabling it would break name
        # resolution.
        services.resolved = {
          enable = true;
          settings.Resolve.DNSOverTLS = cfg.dnsOverTls;
        };

      };
    };
in
{
  flake.modules.nixos.hardware-networking = mod;

}

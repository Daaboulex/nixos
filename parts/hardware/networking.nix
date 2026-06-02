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
        multicastDns = lib.mkOption {
          type = lib.types.enum [
            "no"
            "resolve"
            "yes"
          ];
          default = "no";
          description = ''
            mDNS (.local) resolver. "no" = avahi (nss-mdns) handles it — the fleet
            default. "resolve"/"yes" = systemd-resolved does mDNS PER-LINK instead,
            which resolves over the LAN regardless of VPN/default-route state
            (avahi's nss-mdns does its own multicast that follows the default route
            and escapes out a VPN tunnel — the bug this fixes). "resolve" = resolve
            .local only (no advertising). "yes" = resolve + advertise (host is
            discoverable). For "resolve"/"yes" the host MUST disable avahi
            (myModules.services.avahi.enable = false) to free UDP 5353, and BOTH
            exclude wg0-mullvad (mDNS/LLMNR off on the tunnel) so resolved neither
            queries .local out the tunnel ("resolve") nor advertises into it ("yes").
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        networking = {
          networkmanager.enable = true;
          # NM per-connection mDNS level, mapped from multicastDns:
          #   "no" → 0 — avahi is the responder; resolved stays off mDNS. With
          #     avahi this MUST be 0, else resolved becomes a SECOND responder that
          #     fights avahi over the .local name and avahi renames itself to -21.
          #   "resolve" → 1 — resolved resolves .local per-link, no advertising.
          #   "yes" → 2 — resolved resolves + advertises.
          networkmanager.connectionConfig."connection.mdns" =
            if cfg.multicastDns == "no" then
              0
            else if cfg.multicastDns == "resolve" then
              1
            else
              2;
          firewall = {
            enable = true;
            allowedTCPPorts = cfg.openPorts;
            allowedTCPPortRanges = cfg.openPortRanges;
            allowedUDPPortRanges = cfg.openPortRanges;
            # mDNS multicast when resolved is the responder (avahi opens 5353 itself).
            allowedUDPPorts = lib.optionals (cfg.multicastDns != "no") [ 5353 ];
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
          # mDNS level from multicastDns (default "no" → avahi handles .local).
          # "resolve"/"yes" make resolved do per-link mDNS — robust across VPN
          # states: it binds the LAN and never follows the default route out the
          # tunnel (the failure mode of avahi's nss-mdns own multicast).
          settings.Resolve.MulticastDNS = cfg.multicastDns;
        };

        # Whenever resolved does mDNS ("resolve" or "yes"), keep mDNS + LLMNR OFF
        # on the Mullvad tunnel: wg0-mullvad carries the MULTICAST flag, so resolved
        # would otherwise QUERY .local out the tunnel (leaking the lookup) and, when
        # advertising, respond on it (leaking the hostname) — and racing the tunnel
        # against the LAN makes .local resolution flaky. Re-fires on every
        # (re)connect via the tunnel interface's device unit.
        systemd.services.mdns-no-wg0-mullvad = lib.mkIf (cfg.multicastDns != "no") {
          description = "Disable mDNS/LLMNR on the Mullvad tunnel (no hostname leak)";
          after = [ "systemd-resolved.service" ];
          bindsTo = [ "sys-subsystem-net-devices-wg0\\x2dmullvad.device" ];
          wantedBy = [ "sys-subsystem-net-devices-wg0\\x2dmullvad.device" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = [
              "${pkgs.systemd}/bin/resolvectl mdns wg0-mullvad no"
              "${pkgs.systemd}/bin/resolvectl llmnr wg0-mullvad no"
            ];
          };
        };

      };
    };
in
{
  flake.modules.nixos.hardware-networking = mod;

}

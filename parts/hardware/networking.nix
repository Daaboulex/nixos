# networking — NetworkManager, firewall, and hostname configuration.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      site,
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
        homeWifi.enable = lib.mkEnableOption ''
          the declarative home WiFi profile. SSID comes from the fleet registry
          (`site.network.wifi.ssid`); the PSK comes from the agenix `wifi` secret
          (env var WIFI_PSK), never entering the Nix store. NetworkManager stores
          PSKs agent-owned (KWallet) by default, so autoconnect has no secret
          before login and retry-loops forever; this writes a system-owned keyfile
          via NM `ensureProfiles` instead. Requires the agenix `wifi` secret
        '';

        lanBridge = {
          enable = lib.mkEnableOption ''
            a LAN bridge (`name`, default br0) that enslaves the wired `uplink`
            so libvirt guests can attach to it for real LAN IPs. The bridge
            inherits the uplink's MAC (DHCP lease preserved) and STP is off (no
            boot forwarding delay). Bridged guest frames bypass host netfilter
            (`bridge-nf-call-*=0`) so guest traffic is not filtered by the host
            firewall/VPN. Enable per-profile — e.g. only in VFIO specialisations;
            a host with no bridged guests does not need it
          '';
          uplink = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "enp14s0";
            description = "Wired interface enslaved into the bridge (host-specific). Required when lanBridge.enable.";
          };
          name = lib.mkOption {
            type = lib.types.str;
            default = "br0";
            description = "Bridge interface name that guests attach to.";
          };
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
          # Home WiFi as a system-owned keyfile (PSK from the agenix `wifi`
          # secret via env substitution → never in the Nix store). Guard the
          # secret path so a misconfigured host fails on the assertion below
          # with a clear message instead of a cryptic "attribute missing".
          networkmanager.ensureProfiles = lib.mkMerge [
            (lib.mkIf cfg.homeWifi.enable {
              environmentFiles = lib.optional (config.age.secrets ? wifi) config.age.secrets.wifi.path;
              profiles.home-wifi = {
                connection = {
                  id = site.network.wifi.ssid;
                  type = "wifi";
                  autoconnect = true;
                };
                wifi = {
                  mode = "infrastructure";
                  ssid = site.network.wifi.ssid;
                  # Active-probe for the SSID by name. The BCM4331/b43 passive scan
                  # catches this AP's SSID only intermittently (its beacon drops out
                  # of scans while the co-located SSID stays), so a passive-only
                  # profile fails with "network could not be found". Probing finds it.
                  hidden = true;
                };
                wifi-security = {
                  key-mgmt = "wpa-psk";
                  psk = "$WIFI_PSK";
                };
              };
            })
            (lib.mkIf cfg.lanBridge.enable {
              # br0 bridge + an ethernet slave that enslaves the uplink. STP off
              # (single uplink, no loop) → no forwarding delay at boot. The bridge
              # inherits the uplink's MAC, so the DHCP lease is preserved.
              profiles.${cfg.lanBridge.name} = {
                connection = {
                  id = cfg.lanBridge.name;
                  type = "bridge";
                  interface-name = cfg.lanBridge.name;
                  autoconnect = true;
                  autoconnect-priority = 100;
                  autoconnect-slaves = 1;
                };
                bridge.stp = false;
                ipv4.method = "auto";
                ipv6.method = "auto";
              };
              profiles."${cfg.lanBridge.name}-${cfg.lanBridge.uplink}" = {
                connection = {
                  id = "${cfg.lanBridge.name}-${cfg.lanBridge.uplink}";
                  type = "ethernet";
                  interface-name = cfg.lanBridge.uplink;
                  master = cfg.lanBridge.name;
                  slave-type = "bridge";
                  autoconnect = true;
                  autoconnect-priority = 100;
                };
              };
            })
          ];
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

        # Bridged guest frames bypass host netfilter so the guest's firewall/VPN
        # is its own concern, not the host's (the host still filters its own
        # traffic — only L2-forwarded bridge frames skip iptables).
        boot.kernelModules = lib.mkIf cfg.lanBridge.enable [ "br_netfilter" ];
        boot.kernel.sysctl = lib.mkIf cfg.lanBridge.enable {
          "net.bridge.bridge-nf-call-iptables" = 0;
          "net.bridge.bridge-nf-call-ip6tables" = 0;
          "net.bridge.bridge-nf-call-arptables" = 0;
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

        assertions =
          lib.optionals cfg.homeWifi.enable [
            {
              assertion = config.age.secrets ? wifi;
              message = "myModules.hardware.networking.homeWifi: needs the agenix `wifi` secret — add `myModules.security.agenix.secrets.wifi = { };` to this host.";
            }
            {
              assertion = (site.network.wifi.ssid or "") != "";
              message = "myModules.hardware.networking.homeWifi: needs `site.network.wifi.ssid` set in the fleet registry.";
            }
          ]
          ++ lib.optional cfg.lanBridge.enable {
            assertion = cfg.lanBridge.uplink != "";
            message = "myModules.hardware.networking.lanBridge.uplink: set the wired interface to enslave into ${cfg.lanBridge.name} when lanBridge.enable.";
          };

      };
    };
in
{
  flake.modules.nixos.hardware-networking = mod;

}

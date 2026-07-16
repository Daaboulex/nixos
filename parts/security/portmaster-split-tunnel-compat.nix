# portmaster-split-tunnel-compat — keeps Portmaster's DNS verdicts off the
# split-tunnel resolver chain.
#
# Problem (measured live on the running stack): with
# `filter/dnsQueryInterception=false` Portmaster no longer DNATs foreign
# port-53 packets, but its nfqueue still observes them and applies
# resolver-compliance verdicts per connection. The office zone is a unicast
# `.local` domain: Portmaster scopes `.local` to mDNS exclusively, and with
# `dns/noAssignedNameservers=true` (load-bearing on these hosts, see the
# portmaster block in the host configs) no compliant resolver exists for that
# scope at all — so office-name queries to the loopback rewriter flap between
# pass and block (ICMP host unreachable), one verdict per connection: office
# names randomly stop resolving while every other lookup keeps working.
#
# Portmaster cannot simply be given these names instead: per-domain resolver
# scoping does not exist upstream (safing/docs#106 is an open feature
# request), and answers straight from the office DNS would carry the real
# office addresses, which a colliding LAN cannot route — the alias rewriter
# must stay in the path (see parts/services/split-tunnel.nix). So both legs
# of the split-DNS chain — client to rewriter on loopback, and
# rewriter/watchdog to the office DNS through the tunnel — are exempted from
# Portmaster's ingest chains, with the same lifecycle-following keeper the
# Mullvad fwmark fix uses. Both endpoints are IPv4 by construction, so only
# the v4 family is exempted.
{ inputs, ... }:
let
  mod =
    {
      config,
      lib,
      pkgs,
      myLib,
      ...
    }:
    let
      cfg = config.myModules.security.portmasterSplitTunnelCompat;
      resolver = config.myModules.services.splitTunnel.resolver;
      mkRules =
        chain: matches:
        map (m: {
          family = "iptables";
          inherit chain;
          rule = "${m} -j RETURN";
        }) matches;
    in
    {
      _class = "nixos";
      options.myModules.security.portmasterSplitTunnelCompat = {
        enable = lib.mkEnableOption ''
          split-tunnel + Portmaster coexistence. Keep exemption RETURNs at the
          top of Portmaster's ingest chains for the split-tunnel DNS chain
          (the loopback rewriter and the office DNS in alias space), so
          Portmaster's per-connection resolver-compliance verdicts cannot
          block office name resolution. Requires
          myModules.security.portmaster.enable and
          myModules.services.splitTunnel.enable with split-DNS configured
        '';
      };
      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.myModules.security.portmaster.enable;
            message = "myModules.security.portmasterSplitTunnelCompat: requires myModules.security.portmaster.enable=true.";
          }
          {
            assertion = config.myModules.services.splitTunnel.enable;
            message = "myModules.security.portmasterSplitTunnelCompat: requires myModules.services.splitTunnel.enable=true.";
          }
          {
            assertion = resolver.enable;
            message = "myModules.security.portmasterSplitTunnelCompat: split-tunnel split-DNS is off (site.network.vpn dnsDomains/dnsServer empty) -- there is no resolver chain to exempt.";
          }
        ];

        systemd.services.portmaster-split-tunnel-dns-exempt = lib.mkIf resolver.enable (
          myLib.mkPortmasterChainKeeper {
            inherit pkgs;
            description = "Exempt the split-tunnel DNS chain from Portmaster verdicts";
            rules =
              mkRules "PORTMASTER-INGEST-OUTPUT" [
                "-d ${resolver.listen}/32 -p udp -m udp --dport 53"
                "-d ${resolver.listen}/32 -p tcp -m tcp --dport 53"
                "-d ${resolver.aliasDns}/32 -p udp -m udp --dport 53"
                "-d ${resolver.aliasDns}/32 -p tcp -m tcp --dport 53"
              ]
              ++ mkRules "PORTMASTER-INGEST-INPUT" [
                "-s ${resolver.listen}/32 -p udp -m udp --sport 53"
                "-s ${resolver.listen}/32 -p tcp -m tcp --sport 53"
                "-s ${resolver.aliasDns}/32 -p udp -m udp --sport 53"
                "-s ${resolver.aliasDns}/32 -p tcp -m tcp --sport 53"
              ];
          }
        );
      };
    };
in
{
  flake.modules.nixos.security-portmaster-split-tunnel-compat = mod;
}

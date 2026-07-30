# split-tunnel -- on-demand split-tunnel OpenVPN for remote access to a private
# LAN's internal services (file shares, mail) via NetworkManager.
#
# Works on ANY local network: the remote subnets are never routed directly.
# Each routed /24 is presented to this machine under a private ALIAS /24
# (`aliasNet` + the real third octet). The tunnel routes only the alias; an
# nftables netmap rewrites alias->real on egress into the tunnel (conntrack
# reverses the replies, the source stays the VPN-assigned address, so the
# server side needs no cooperation); a loopback dnsmasq forwards the internal
# domains to the remote DNS and rewrites its answers into alias space, so
# names keep working transparently. A LAN that shares the remote's subnet can
# no longer collide -- only a LAN inside `aliasNet` could, and the connect-time
# guard tears the tunnel down for that (fail-closed). On a LAN that does NOT
# collide with a routed /24, the real subnet is ALSO routed through the tunnel
# (adaptive: added per-subnet at vpn-up only when no local address falls inside
# it), so by-IP access -- server-issued redirects to internal IPs, IP bookmarks,
# the remote builder -- keeps working everywhere except on a colliding LAN,
# where only names/aliases can work. A liveness watchdog tears down a tunnel
# whose data channel has died while NM still shows it active (nm-openvpn
# soft-restart loops on hostile NATs), so a dead office link is visible in the
# tray instead of silently hanging every connection. Never a default route,
# so general/web traffic stays on the normal connection and a flaky tunnel
# never breaks anything but access to those internal services. On-demand from
# the KDE tray (autoconnect off). All site-specific values (server, username,
# display name, routed subnets, internal domain/DNS, the X.509 subject) live
# in the PRIVATE site registry; the client PKI lives in agenix; the login
# password is agenix system-owned.
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
      cfg = config.myModules.services.splitTunnel;
      vpn = site.network.vpn or { };

      # KDE tray label comes from the private site (so the public module names no
      # company). A PINNED uuid keeps the profile identity stable across rebuilds
      # (ensureProfiles rewrites the keyfile each switch).
      connName = vpn.name or "Work VPN";
      connUuid = "fa41fa41-0000-4000-8000-000000000001";

      secretNames = [
        "split-tunnel-ca"
        "split-tunnel-cert"
        "split-tunnel-key"
      ];
      haveSecret = n: config.age.secrets ? ${n};
      secretPath = n: config.age.secrets.${n}.path;

      routedSubnets = vpn.routedSubnets or [ ];
      dnsDomains = vpn.dnsDomains or [ ];
      dnsServer = vpn.dnsServer or "";

      # ["a" "b" "c"] of an `a.b.c.0/24`, null for any other shape -> the /24
      # assertion below fails closed (netmap, guard, and DNS rewrite all reason
      # only about /24s).
      subnetOctets = sub: builtins.match "([0-9]+)\\.([0-9]+)\\.([0-9]+)\\.0/24" sub;
      netAddr = sub: (lib.concatStringsSep "." (subnetOctets sub)) + ".0";

      # real a.b.c.0/24 -> alias <aliasNet>.c.0/24 (third octet preserved).
      aliasFor =
        sub:
        let
          m = subnetOctets sub;
        in
        if m == null then null else "${cfg.aliasNet}.${builtins.elemAt m 2}.0/24";
      aliasSubnets = map aliasFor routedSubnets;
      subnetPairs = lib.zipListsWith (real: alias: { inherit real alias; }) routedSubnets aliasSubnets;
      # "a.b.c." of an a.b.c.0/24 -- the guard and the adaptive real-route
      # match local addresses against these.
      prefixOf = s: (lib.concatStringsSep "." (subnetOctets s)) + ".";
      aliasPrefixes = map prefixOf aliasSubnets;

      # host IP inside a routed /24 -> the same host in alias space; null if the
      # IP lies in none of the routed subnets (asserted below for the DNS server).
      aliasHost =
        ip:
        let
          m = builtins.match "([0-9]+)\\.([0-9]+)\\.([0-9]+)\\.([0-9]+)" ip;
          hit =
            if m == null then
              null
            else
              lib.findFirst (r: subnetOctets r == lib.sublist 0 3 m) null routedSubnets;
        in
        if hit == null then null else "${cfg.aliasNet}.${builtins.elemAt m 2}.${builtins.elemAt m 3}";

      dnsEnabled = dnsDomains != [ ] && dnsServer != "";
      dnsListen = "127.0.0.153";

      # Office hosts absent from the remote zone (a machine with a static IP
      # that never self-registers the way Windows did): answered
      # authoritatively here, in alias space, straight from the site
      # registry. The long-term fix is the A record on the remote DNS; this
      # keeps the name working over the tunnel meanwhile and can never
      # disagree with it (same registry feeds the host's own static config).
      hostRecordArgs = map (
        r:
        let
          a = aliasHost (r.ip or "");
        in
        if a == null then
          throw "myModules.services.splitTunnel: site.network.vpn.hostRecords entry `${r.name or "?"}` needs an ip inside routedSubnets"
        else
          "--host-record=${r.name}.${builtins.head dnsDomains},${a}"
      ) (vpn.hostRecords or [ ]);
      aliasDns =
        let
          a = aliasHost dnsServer;
        in
        if a == null then
          throw "myModules.services.splitTunnel: site.network.vpn.dnsServer (${dnsServer}) must lie inside one of routedSubnets"
        else
          a;

      # fwmark pins netmap'd packets to the alias routing table across the
      # post-DNAT reroute; both values are arbitrary and must merely be unused
      # on the host (Mullvad marks 0x6d6f6c65; libvirt uses none). The rule
      # preference must sit BEFORE Mullvad's policy rules (suppress_prefixlength
      # at 32764, catch-all at 32765) or the marked packets get swallowed by
      # the Mullvad catch-all whenever both tunnels are up.
      fwmark = "0x5354";
      rtable = "3982";
      rulePref = "100";
      tableName = "split-tunnel-alias";

      # NM keyfile routes are numbered keys (route1, route2, ...) merged into [ipv4].
      routeAttrs = builtins.listToAttrs (
        lib.imap1 (i: s: lib.nameValuePair "route${toString i}" s) aliasSubnets
      );

      # alias->real netmap on locally generated traffic entering the tunnel.
      # /24-only bitwise form (host byte kept, network bytes replaced); loaded
      # by the dispatcher on vpn-up, deleted on vpn-down -- nothing dormant.
      #
      # Two chains because the two marks have different lifetimes. The skb
      # fwmark steers each packet's post-NAT reroute into the alias routing
      # table, and an skb mark lives on ONE packet -- while a nat-hook chain
      # sees only a flow's FIRST packet (conntrack rewrites the rest without
      # re-running the rules). Set there, every later packet rerouted to its
      # conntrack-translated REAL destination via the MAIN table -- on a LAN
      # that collides with a routed subnet that egresses the local LAN, not
      # the tunnel: handshakes complete, then all data leaks and dies. So the
      # fwmark is set in a route-hook chain (priority mangle, -150), which
      # runs for EVERY output packet and still sees the pre-NAT alias daddr
      # (conntrack's rewrite happens later, at nat priority -100).
      #
      # The office-DNS flows additionally get Mullvad's split-tunnel conntrack
      # mark 0x00000f41 (its officially documented escape hatch): Mullvad's
      # firewall rejects every port-53 packet not aimed at its own resolver --
      # on all interfaces, ahead of its allow-LAN rule -- but accepts flows
      # carrying that ct mark, so the rewriter's forwards and the watchdog's
      # probes survive a connected Mullvad. Only these flows are stamped: the
      # outer OpenVPN transport must keep nesting through the Mullvad tunnel,
      # and non-DNS traffic already passes via allow-LAN. A ct mark persists
      # on the conntrack ENTRY, so first-packet stamping in the nat chain is
      # correct for it -- unlike the per-packet fwmark above.
      nftRuleset = pkgs.writeText "split-tunnel-alias.nft" ''
        table ip ${tableName} {
          chain alias-mark {
            type route hook output priority mangle; policy accept;
        ${
          lib.concatMapStrings (p: ''
            ip daddr ${p.alias} meta mark set ${fwmark}
          '') subnetPairs
        }  }
          chain output {
            type nat hook output priority -100; policy accept;
        ${lib.optionalString dnsEnabled ''
          ip daddr ${aliasDns} udp dport 53 ct mark set 0x00000f41
          ip daddr ${aliasDns} tcp dport 53 ct mark set 0x00000f41
        ''}${
          lib.concatMapStrings (p: ''
            ip daddr ${p.alias} dnat to ip daddr and 0.0.0.255 or ${netAddr p.real}
          '') subnetPairs
        }  }
        }
      '';

      # Connect-time lifecycle. Runs for every NM event but no-ops unless THIS
      # VPN changed state. vpn-up: guard (a local LAN inside the ALIAS range is
      # the one remaining collision -> tear down, fail closed), then load the
      # netmap, pin the rewritten destinations to the tunnel via fwmark/rtable,
      # add the real /24 for every routed subnet the local LAN does NOT occupy
      # (by-IP access + a valid reverse path for the un-NAT'd reply source),
      # and start the liveness watchdog. vpn-down: remove all of it. Self-
      # contained: all tools by absolute path (dispatcher runs with a bare PATH).
      lifecycle = pkgs.writeShellScript "split-tunnel-lifecycle" ''
        # $1 = interface, $2 = action. NM also exports CONNECTION_ID / CONNECTION_UUID.
        IP=${pkgs.iproute2}/bin/ip
        NFT=${pkgs.nftables}/bin/nft
        NMCLI=${pkgs.networkmanager}/bin/nmcli
        SYSTEMCTL=${pkgs.systemd}/bin/systemctl
        AWK=${pkgs.gawk}/bin/awk

        # Route each real /24 through the tunnel only while no local address
        # occupies it. Runs at vpn-up and again on every OTHER interface
        # up/down while the tunnel is live, so docking onto a colliding LAN
        # mid-session drops the shadowing route within a second, and leaving
        # that LAN restores the by-IP path. Alias routes are untouched.
        sync_real_routes() {
          tun="$1"
          addrs=$("$IP" -4 -o addr show 2>/dev/null | "$AWK" -v ifc="$tun" '$2 != ifc { print $4 }')
        ${
          lib.concatMapStrings (p: ''
            case "$addrs" in
              *"${prefixOf p.real}"*) "$IP" route del ${netAddr p.real}/24 dev "$tun" metric 50 2>/dev/null || true ;;
              *) "$IP" route replace ${netAddr p.real}/24 dev "$tun" metric 50 ;;
            esac
          '') subnetPairs
        }  }

        if [ "''${CONNECTION_ID:-}" != ${lib.escapeShellArg connName} ]; then
          # Another connection changed. If our tunnel is up, adapt the
          # real-routes to the new local-address reality; no-op otherwise.
          case "''${2:-}" in
            up | down)
              tun=$("$IP" route show table ${rtable} 2>/dev/null | "$AWK" '{ print $3; exit }')
              [ -n "$tun" ] && sync_real_routes "$tun"
              ;;
          esac
          exit 0
        fi

        teardown() {
          echo "split-tunnel: $1 -- tearing down the tunnel" >&2
          "$NMCLI" connection down "''${CONNECTION_UUID:-${connName}}" >/dev/null 2>&1 || true
          exit 0
        }

        case "''${2:-}" in
          vpn-up)
            iface="$1"
            addrs=$("$IP" -4 -o addr show 2>/dev/null \
              | "$AWK" -v ifc="$iface" '$2 != ifc { print $4 }')
            for p in ${lib.concatStringsSep " " aliasPrefixes}; do
              case "$addrs" in
                *"$p"*) teardown "local LAN overlaps the alias range (''${p}0/24); set myModules.services.splitTunnel.aliasNet to a range no LAN you use" ;;
              esac
            done

            "$NFT" -f ${nftRuleset} || teardown "nftables netmap failed to load (no alias translation)"
            rules=$("$IP" rule list)
            case "$rules" in
              *"lookup ${rtable}"*) : ;;
              *) "$IP" rule add pref ${rulePref} fwmark ${fwmark} table ${rtable} ;;
            esac
        ${
          lib.concatMapStrings (p: ''
            "$IP" route replace ${netAddr p.real}/24 dev "$iface" table ${rtable}
          '') subnetPairs
        }    sync_real_routes "$iface"
        ${lib.optionalString dnsEnabled ''
          "$SYSTEMCTL" start split-tunnel-watchdog.service 2>/dev/null || true
        ''}    ;;
          vpn-down)
        ${lib.optionalString dnsEnabled ''
          "$SYSTEMCTL" stop split-tunnel-watchdog.service 2>/dev/null || true
        ''}    "$IP" route flush table ${rtable} 2>/dev/null || true
            "$IP" rule del fwmark ${fwmark} table ${rtable} 2>/dev/null || true
            "$NFT" delete table ip ${tableName} 2>/dev/null || true
            ;;
        esac
        exit 0
      '';
    in
    {
      _class = "nixos";

      options.myModules.services.splitTunnel = {
        enable = lib.mkEnableOption ''
          an on-demand split-tunnel OpenVPN (toggled from the KDE tray) that
          presents `site.network.vpn.routedSubnets` under a private alias range
          and routes ONLY that alias through the tunnel (nftables netmap +
          DNS-answer rewrite), so it works on any local network -- no default
          route, web/general traffic and the local LAN are untouched. All
          site-specific values come from `site.network.vpn`; the client PKI from
          the agenix secrets `${lib.concatStringsSep "`, `" secretNames}` and the
          login password from the agenix `split-tunnel-pass` secret
          (system-owned, never prompts). A connect-time guard tears the tunnel
          down on a LAN that overlaps the ALIAS range
        '';

        aliasNet = lib.mkOption {
          type = lib.types.strMatching "[0-9]+\\.[0-9]+";
          default = "10.199";
          description = ''
            First two octets of the private alias space the routed subnets are
            presented under (a routed a.b.c.0/24 appears locally as
            <aliasNet>.c.0/24). Pick a range no LAN you use hands out; the
            connect-time guard fails closed if one does. Avoid 100.64
            (CGNAT/tailscale).
          '';
        };

        resolver = lib.mkOption {
          readOnly = true;
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                description = "Whether the split-DNS chain (loopback rewriter + scoped routing) is configured.";
              };
              listen = lib.mkOption {
                type = lib.types.str;
                description = "Loopback address the alias-space DNS rewriter listens on.";
              };
              aliasDns = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                description = "The office DNS server in alias space; null while split-DNS is off.";
              };
            };
          };
          default = {
            enable = dnsEnabled;
            listen = dnsListen;
            aliasDns = if dnsEnabled then aliasDns else null;
          };
          defaultText = lib.literalMD "derived from `site.network.vpn`";
          description = ''
            Read-only contract of the DNS chain this module runs, for modules
            that must cooperate with it (portmaster-split-tunnel-compat keeps
            Portmaster's verdicts off exactly these endpoints).
          '';
        };

        dataPlane = lib.mkOption {
          readOnly = true;
          type = lib.types.submodule {
            options = {
              ruleset = lib.mkOption {
                type = lib.types.package;
                description = "The nftables ruleset the dispatcher loads at vpn-up.";
              };
              lifecycle = lib.mkOption {
                type = lib.types.package;
                description = "The dispatcher lifecycle script (guard, netmap, routes, watchdog, teardown).";
              };
              tableName = lib.mkOption {
                type = lib.types.str;
                description = "Name of the nftables table the netmap lives in.";
              };
              fwmark = lib.mkOption {
                type = lib.types.str;
                description = "The skb mark that pins aliased packets to the alias routing table.";
              };
              rtable = lib.mkOption {
                type = lib.types.str;
                description = "The routing table the fwmark rule selects.";
              };
            };
          };
          default = {
            ruleset = nftRuleset;
            inherit
              lifecycle
              tableName
              fwmark
              rtable
              ;
          };
          defaultText = lib.literalMD "the module's generated artifacts and constants";
          description = ''
            Read-only handles to the generated data-plane artifacts and the
            constants they use, so the VM regression test (and any module
            that must cooperate) references the module's actual values --
            never a restated copy that could silently drift.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.networking.networkmanager.enable;
            message = "myModules.services.splitTunnel: needs NetworkManager (set myModules.hardware.networking.enable = true on this host).";
          }
          {
            assertion = (vpn.server or "") != "";
            message = "myModules.services.splitTunnel: set site.network.vpn.server (the OpenVPN remote host) in the site registry.";
          }
          {
            assertion = routedSubnets != [ ];
            message = "myModules.services.splitTunnel: site.network.vpn.routedSubnets is empty -- nothing would be routed through the tunnel.";
          }
          {
            assertion = !(lib.elem null (map subnetOctets routedSubnets));
            message = "myModules.services.splitTunnel: every site.network.vpn.routedSubnets entry must be a `.0/24` -- the netmap, the DNS rewrite, and the overlap guard all reason only about /24s.";
          }
          {
            assertion = lib.unique aliasSubnets == aliasSubnets;
            message = "myModules.services.splitTunnel: two routedSubnets share a third octet, so their aliases collide -- the alias derivation needs distinct third octets.";
          }
          {
            assertion = !(lib.any (a: lib.elem a routedSubnets) aliasSubnets);
            message = "myModules.services.splitTunnel: the alias range overlaps a routed subnet -- set aliasNet to a range disjoint from routedSubnets.";
          }
          {
            assertion = config.age.secrets ? "split-tunnel-pass";
            message = "myModules.services.splitTunnel: needs the agenix `split-tunnel-pass` secret (env file `SPLIT_TUNNEL_PASS=<vpn password>`) -- add `myModules.security.agenix.secrets.split-tunnel-pass = { };` to this host.";
          }
          {
            assertion = (vpn.hostRecords or [ ]) == [ ] || dnsEnabled;
            message = "myModules.services.splitTunnel: site.network.vpn.hostRecords is set but split-DNS is off (dnsDomains/dnsServer empty) -- no resolver would ever serve those records.";
          }
        ]
        ++ map (n: {
          assertion = haveSecret n;
          message = "myModules.services.splitTunnel: needs the agenix `${n}` secret -- add `myModules.security.agenix.secrets.${n} = { };` to this host.";
        }) secretNames;

        # The split-tunnel profile. NM feeds the ALIAS routes + scoped split-DNS
        # to systemd-resolved and cleans them up on disconnect. never-default +
        # ignore-auto-* mean the server can neither push a default route nor
        # override DNS. Merges with the home-wifi profile from hardware-networking.
        networking.networkmanager.ensureProfiles.profiles.split-tunnel = {
          connection = {
            id = connName;
            uuid = connUuid;
            type = "vpn";
            autoconnect = false;
          };
          vpn = {
            service-type = "org.freedesktop.NetworkManager.openvpn";
            # cert + username/password (the .ovpn carries both client PKI and
            # auth-user-pass).
            connection-type = "password-tls";
            remote = vpn.server;
            port = vpn.port or 1194;
            # UDP (the .ovpn is `proto udp`). nm-openvpn vpn.data booleans are
            # the strings "yes"/"no" -- NOT the true/false used by NM core props.
            proto-tcp = "no";
            # Keepalive under the mobile-NAT floor: tether/CGNAT paths expire
            # idle UDP mappings at ~30 s (Linux conntrack default; carriers
            # violate RFC 4787's 2-minute floor), and a rebound mapping kills
            # the data channel on a server without --float. A server-pushed
            # keepalive overrides this.
            ping = 10;
            # Restart after 45 s of silence (>= 4 lost keepalives, not a
            # blip) instead of OpenVPN's 120 s client default -- recovers
            # ~3x faster when the outer path changes under the tunnel
            # (Mullvad toggle, tether drop). A pushed value still wins.
            ping-restart = 45;
            # Clamp tunneled TCP MSS so full-size flows (SMB, HTTPS) never
            # fragment the outer UDP -- fragmented UDP is the first
            # casualty on mobile/CGNAT paths. 1360 still fits when the
            # outer flow nests inside WireGuard (Mullvad): 1360 + ~70
            # OpenVPN + 60 WireGuard < 1500. (explicit-exit-notify is NOT
            # a supported nm-openvpn 1.12 key -- rejected as BadArguments.)
            mssfix = 1360;
            ca = secretPath "split-tunnel-ca";
            cert = secretPath "split-tunnel-cert";
            key = secretPath "split-tunnel-key";
            # 0 = system-owned: NM stores the password in the connection itself.
            # We feed it from the agenix `split-tunnel-pass` secret via the
            # ensureProfiles env-substitution (`$SPLIT_TUNNEL_PASS`), mirroring the
            # wifi PSK -- so NM never prompts, independent of KDE's (flaky, dual
            # kwalletd/ksecretd) secret store.
            password-flags = 0;
            # The client key from the .ovpn is an UNENCRYPTED PKCS#8 key
            # (`BEGIN PRIVATE KEY`, no passphrase). 4 = NOT_REQUIRED so NM never
            # prompts for a key password that does not exist.
            cert-pass-flags = 4;
            remote-cert-tls = "server";
            verify-x509-name = vpn.verifyX509Name or "";
          }
          # The .ovpn uses a bare `auth-user-pass` (no username baked in), so by
          # default NM prompts for BOTH username and password. Pin a username ONLY
          # if site.network.vpn.username is non-empty (then NM prompts for the
          # password alone). Empty/unset => prompt for both -- never assume one.
          // lib.optionalAttrs ((vpn.username or "") != "") {
            inherit (vpn) username;
          };
          ipv4 = {
            method = "auto";
            never-default = true; # do not take the server-pushed default route
            ignore-auto-routes = true; # ignore ALL pushed routes; we add only ours
            ignore-auto-dns = true; # ignore pushed DNS; we set the scoped split-DNS
            # NM core adds a /32 pin to the VPN server via the physical gateway
            # for EVERY VPN (unconditional, independent of redirect-gateway).
            # 0 = skip it, so the OUTER transport follows the system default
            # route -- it nests through a full-tunnel VPN (e.g. Mullvad) instead
            # of being forced direct, which that VPN's leak firewall would block.
            # The intended NM fix for OpenVPN-over-VPN (NM-openvpn issue #62);
            # needs NM >= 1.42. Declarative -- no runtime route surgery, no marks.
            # NMTernary in a keyfile must be an integer (0=false); NM rejects a
            # literal false with "value cannot be interpreted as integer".
            auto-route-ext-gw = 0;
            # While the tunnel is up, resolved routes `dnsDomains` to the local
            # rewrite resolver (split-tunnel-dns), which answers in alias space.
            dns = if dnsEnabled then "${dnsListen};" else "";
            # ~domain = a routing-only domain: ONLY these names resolve via the
            # tunnel DNS; everything else stays on the global (Mullvad DoT) resolver.
            dns-search = lib.concatMapStrings (d: "~${d};") dnsDomains;
            dns-priority = -42; # prefer this resolver for its routing domains
          }
          // routeAttrs;
          ipv6 = {
            method = "disabled"; # server is v4-only; no v6 leak
            auto-route-ext-gw = 0; # same pin-suppression on v6 (belt-and-suspenders)
          };
          # Login password, substituted from the agenix `split-tunnel-pass` secret
          # (env file `SPLIT_TUNNEL_PASS=<password>`) via environmentFiles below.
          vpn-secrets.password = "$SPLIT_TUNNEL_PASS";
        };

        # Make the agenix password available to the env-substitution above
        # (systemd EnvironmentFile -> envsubst). Merges with hardware-networking's
        # wifi entry. Guarded so a host without the secret fails the assertion above.
        networking.networkmanager.ensureProfiles.environmentFiles = lib.optional (
          config.age.secrets ? "split-tunnel-pass"
        ) config.age.secrets."split-tunnel-pass".path;

        networking.networkmanager.dispatcherScripts = [
          {
            source = lifecycle;
            type = "basic";
          }
        ];

        # Zombie-tunnel watchdog. nm-openvpn soft-restarts forever on a path
        # whose data channel is dead (handshake completes, then total silence,
        # ping-restart every 120 s) while NM keeps the VPN "activated" -- every
        # office connection then hangs with no visible cause. Probe the real
        # service the tunnel exists for (a DNS query to the internal resolver,
        # dialed via its alias, i.e. through the tunnel data path); after 4
        # consecutive misses (~80 s) tear the tunnel down -- plasma-nm surfaces
        # the disconnect natively and reconnecting is one tray click. Started
        # and stopped only by the dispatcher: nothing dormant while the VPN is
        # down, and a manual `systemctl start` without the tunnel just tears
        # down an already-down connection (harmless no-op).
        systemd.services.split-tunnel-watchdog = lib.mkIf dnsEnabled {
          description = "split-tunnel liveness watchdog";
          serviceConfig.Type = "simple";
          script = ''
            sleep 15 # connect grace: routes + first exchanges settle
            fails=0
            while true; do
              if ${pkgs.dnsutils}/bin/dig +time=2 +tries=1 "@${aliasDns}" ${builtins.head dnsDomains} SOA >/dev/null 2>&1; then
                fails=0
              else
                fails=$((fails + 1))
                if [ "$fails" -ge 4 ]; then
                  echo "split-tunnel: ${aliasDns} gave no DNS answer for $fails probes -- tearing down the dead tunnel" >&2
                  ${pkgs.networkmanager}/bin/nmcli connection down "${connUuid}" >/dev/null 2>&1 || true
                  exit 0
                fi
              fi
              sleep 20
            done
          '';
        };

        # The alias-space resolver: forwards ONLY the internal domains to the
        # remote DNS (dialed via its alias, i.e. through the tunnel) and rewrites
        # the answers real->alias (dnsmasq's NAT doctoring). Idle unless the
        # tunnel is up: resolved only routes `dnsDomains` here while the NM
        # profile is active. Reverse lookups of alias IPs are not rewritten
        # (cosmetic; --alias doctors A records only).
        systemd.services.split-tunnel-dns = lib.mkIf dnsEnabled {
          description = "split-tunnel alias-space DNS rewriter";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = lib.concatStringsSep " " (
              [
                "${pkgs.dnsmasq}/bin/dnsmasq"
                "--keep-in-foreground"
                "--port=53"
                "--listen-address=${dnsListen}"
                "--bind-interfaces"
                "--no-resolv"
                "--no-hosts"
                "--cache-size=256"
              ]
              ++ map (d: "--server=/${d}/${aliasDns}") dnsDomains
              ++ map (p: "--alias=${netAddr p.real},${netAddr p.alias},255.255.255.0") subnetPairs
              ++ hostRecordArgs
            );
            DynamicUser = true;
            AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
            CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
            NoNewPrivileges = true;
            Restart = "on-failure";
          };
        };
      };
    };
in
{
  flake.modules.nixos.services-split-tunnel = mod;
}

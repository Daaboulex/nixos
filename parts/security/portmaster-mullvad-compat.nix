# portmaster-mullvad-compat — preserves Mullvad's WireGuard fwmark across Portmaster's CONNMARK --restore-mark.
#
# Problem (evidence: `ip rule show` on a live system):
#   32765:  not from all fwmark 0x6d6f6c65 lookup 1836018789
# Userspace wireguard-go (Mullvad's Linux default) sets SO_MARK=0x6d6f6c65
# on every encapsulated UDP packet so the policy rule can route those
# packets out the physical interface instead of looping back into
# wg0-mullvad.
#
# Portmaster installs this rule (service/firewall/interception/nfqueue_linux.go):
#   mangle PORTMASTER-INGEST-OUTPUT -m mark ! --mark 0 -m connmark --mark 1710 -j RETURN
#   mangle PORTMASTER-INGEST-OUTPUT -j CONNMARK --restore-mark
#   mangle PORTMASTER-INGEST-OUTPUT -m mark --mark 0 -j NFQUEUE --queue-num 17040 --queue-bypass
# The first rule RETURNs only for connections already marked AcceptAlways
# (connmark 1710). On a fresh connection that mark doesn't exist yet, so
# `CONNMARK --restore-mark` overwrites the packet mark with the conntrack
# mark (zero), destroying Mullvad's 0x6d6f6c65 tag. The policy rule then
# routes the encapsulated packet back into wg0-mullvad → infinite loop →
# kernel drops → no tunnel.
#
# Upstream Portmaster comment acknowledges the class of issue:
#   // Preserve original packet marks for permanently allowed connections
#   // (connmark 1710/AcceptAlways)... Example: WireGuard/wg-quick relies
#   // on packet marks; changing them would break its routing.
# But the protection is connmark-gated, which doesn't help on fresh
# connections before Portmaster has had a chance to apply AcceptAlways.
#
# Fix: insert an unconditional RETURN at slot 1 of PORTMASTER-INGEST-OUTPUT
# for any packet already carrying Mullvad's fwmark. Runs pre-restore-mark,
# so Mullvad's tag survives intact.
#
# Implemented as a systemd oneshot bound to portmaster.service so it
# follows the start/stop/restart lifecycle — when Portmaster pauses (chain
# removed) our rule disappears with it; when Portmaster re-creates its
# chains, our rule is re-installed.
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
      cfg = config.myModules.security.portmasterMullvadCompat;
    in
    {
      _class = "nixos";
      options.myModules.security.portmasterMullvadCompat = {
        enable = lib.mkEnableOption ''
          Mullvad + Portmaster coexistence. Insert an iptables RETURN rule
          at the top of PORTMASTER-INGEST-OUTPUT so Portmaster does not
          overwrite Mullvad's fwmark on WireGuard-encapsulated packets.
          Requires both myModules.security.portmaster.enable and an active
          Mullvad daemon — the rule is harmless when Mullvad is stopped
        '';
        mark = lib.mkOption {
          type = lib.types.str;
          default = "0x6d6f6c65";
          description = ''
            Mullvad's WireGuard fwmark, as hex. Userspace wireguard-go
            stamps this via SO_MARK on every encapsulated UDP packet; the
            matching `ip rule` entry uses `fwmark 0x6d6f6c65`. Mullvad has
            shipped this value since the linux daemon gained userspace WG
            support; changing it here only makes sense if Mullvad upstream
            changes the constant.
          '';
        };
        method = lib.mkOption {
          type = lib.types.enum [
            "poll"
            "connmark"
          ];
          default = "poll";
          description = ''
            How to preserve Mullvad's fwmark across Portmaster's restore-mark.

            "poll" (default, PROVEN): a watcher re-inserts an iptables RETURN at
            the top of PORTMASTER-INGEST-OUTPUT whenever Portmaster (re)creates
            the chain. The RETURN runs INSIDE Portmaster's own chain, before its
            CONNMARK --restore-mark, so the mole-mark survives. This is the only
            mechanism verified to work; cost is a 1 Hz poll + coupling to
            Portmaster's chain name.

            "connmark" (UNVERIFIED — runtime-test before relying on it): an
            independent nft table seeds the conntrack mark with the mole-mark
            BEFORE Portmaster (priority mangle - 10), so Portmaster's own
            restore-mark reinstates it. No poll, no chain-name coupling, survives
            pause/resume by table ownership. BUT it silently depends on
            Portmaster restoring the FULL mark mask — a restricted nfmask/ctmask
            would drop the mole bits and break the tunnel on fresh connections.
            Validate with the AUDIT.md §17.1 checklist, then keep or revert.
          '';
        };
      };
      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.myModules.security.portmaster.enable;
            message = "myModules.security.portmasterMullvadCompat: requires myModules.security.portmaster.enable=true.";
          }
          {
            assertion = config.myModules.services.mullvad.enable;
            message = "myModules.security.portmasterMullvadCompat: requires myModules.services.mullvad.enable=true.";
          }
        ];

        # The lifecycle problem (chains re-created on filtering start, removed
        # on UI "Pause") and the poll answer live in the shared keeper:
        # lib/mkPortmasterChainKeeper.nix.
        systemd.services.portmaster-mullvad-fwmark-preserve = lib.mkIf (cfg.method == "poll") (
          myLib.mkPortmasterChainKeeper {
            inherit pkgs;
            description = "Preserve Mullvad fwmark through Portmaster's CONNMARK restore";
            rules =
              lib.concatMap
                (
                  family:
                  map
                    (chain: {
                      inherit family chain;
                      rule = "-m mark --mark ${cfg.mark} -j RETURN";
                    })
                    [
                      "PORTMASTER-INGEST-OUTPUT"
                      "PORTMASTER-INGEST-INPUT"
                    ]
                )
                [
                  "iptables"
                  "ip6tables"
                ];
          }
        );

        # v2 (method = "connmark", UNVERIFIED — runtime-test before trusting):
        # an independent nft table seeds the conntrack mark with the mole-mark
        # before Portmaster (priority mangle - 10), letting Portmaster's own
        # restore-mark reinstate it. Loaded via `nft -f` as a standalone table
        # (NOT networking.nftables.enable, which would flip the whole firewall
        # backend) — so it survives Portmaster pause/resume by table ownership,
        # no poll, no chain-name coupling. See AUDIT.md §17.1.
        systemd.services.portmaster-mullvad-connmark-seed = lib.mkIf (cfg.method == "connmark") {
          description = "Seed conntrack mark with Mullvad fwmark before Portmaster (v2)";
          bindsTo = [ "portmaster.service" ];
          after = [ "portmaster.service" ];
          wantedBy = [ "portmaster.service" ];
          path = [ pkgs.nftables ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = "nft -f ${pkgs.writeText "mullvad-portmaster-repair.nft" ''
            table inet mullvad-portmaster-repair {
              chain save-mole-connmark {
                type filter hook output priority mangle - 10; policy accept;
                meta mark ${cfg.mark} ct mark set ${cfg.mark}
              }
            }
          ''}";
          preStop = "nft delete table inet mullvad-portmaster-repair 2>/dev/null || true";
        };
      };
    };
in
{
  flake.modules.nixos.security-portmaster-mullvad-compat = mod;
}

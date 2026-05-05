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

        systemd.services.portmaster-mullvad-fwmark-preserve = {
          description = "Preserve Mullvad fwmark through Portmaster's CONNMARK restore";
          bindsTo = [ "portmaster.service" ];
          after = [ "portmaster.service" ];
          wantedBy = [ "portmaster.service" ];
          path = [
            pkgs.iptables
            pkgs.gnused
          ];
          serviceConfig = {
            Type = "simple";
            Restart = "on-failure";
            RestartSec = "5s";
          };
          # Long-running watcher — Portmaster creates its mangle chains
          # when it starts actively filtering, and removes them when the
          # user clicks "Pause" in the UI (chain lifecycle != service
          # lifecycle). A oneshot bound to portmaster.service can race
          # Portmaster's chain creation and fires only once, which
          # silently loses the rule on every pause/resume cycle. Instead
          # we poll every few seconds and re-insert the RETURN at slot 1
          # whenever we see the chain exists without our rule on top. No
          # rule hit = fast path; checks are cheap.
          script = ''
            want_rule='-m mark --mark ${cfg.mark} -j RETURN'
            while true; do
              for fw in iptables ip6tables; do
                for chain in PORTMASTER-INGEST-OUTPUT PORTMASTER-INGEST-INPUT; do
                  # Skip silently when the chain doesn't exist (Portmaster
                  # paused or not yet finished init).
                  $fw -t mangle -L "$chain" >/dev/null 2>&1 || continue
                  # Rule #1 already what we want? Nothing to do.
                  current=$($fw -t mangle -S "$chain" 2>/dev/null | sed -n 2p)
                  expected="-A $chain $want_rule"
                  if [ "$current" = "$expected" ]; then
                    continue
                  fi
                  # Remove any older copies (defensive), then insert fresh.
                  while $fw -t mangle -D "$chain" $want_rule 2>/dev/null; do :; done
                  $fw -t mangle -I "$chain" 1 $want_rule 2>/dev/null || true
                done
              done
              sleep 1
            done
          '';
          preStop = ''
            want_rule='-m mark --mark ${cfg.mark} -j RETURN'
            for fw in iptables ip6tables; do
              for chain in PORTMASTER-INGEST-OUTPUT PORTMASTER-INGEST-INPUT; do
                while $fw -t mangle -D "$chain" $want_rule 2>/dev/null; do :; done
              done
            done
          '';
        };
      };
    };
in
{
  flake.modules.nixos.security-portmaster-mullvad-compat = mod;
}

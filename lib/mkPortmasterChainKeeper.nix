# mkPortmasterChainKeeper — the ONE way to keep exemption rules alive inside
# Portmaster's iptables chains (check-portmaster-chain-ownership enforces it).
#
# Portmaster (re)creates its mangle chains when it starts filtering and
# removes them when paused, so chain lifecycle != service lifecycle: a
# oneshot races the chain creation and its rule silently dies on every
# pause/resume cycle. The keeper is a poll loop bound to portmaster.service
# that re-asserts the given rules as the TOP slots of their chains (in list
# order) whenever a chain exists without them, and removes them on stop.
# No divergence = fast path; the checks are cheap.
#
# Each rule must be spelled EXACTLY as `iptables -S` prints it (CIDR mask on
# addresses, explicit protocol match module: `-d 10.0.0.1/32 -p udp -m udp
# --dport 53`): the keeper compares text, so a spelling iptables normalizes
# differently would delete-and-reinsert on every poll.
#
# rules: [ { family = "iptables" | "ip6tables";
#            chain  = e.g. "PORTMASTER-INGEST-OUTPUT";
#            rule   = "<match+target spec>"; } ]
# Returns the full systemd.services.<name> value.
{
  pkgs,
  description,
  rules,
}:
let
  inherit (pkgs) lib;
  # (family, chain) -> ordered rule list; each group is enforced as slots 1..n.
  groups = lib.attrValues (lib.groupBy (r: "${r.family}/${r.chain}") rules);
  ensure =
    group:
    let
      inherit (builtins.head group) family chain;
      specs = map (r: r.rule) group;
      expected = lib.concatMapStringsSep "\n" (r: "-A ${chain} ${r}") specs;
    in
    ''
      # Chain absent = Portmaster paused or still initializing: skip silently.
      if ${family} -t mangle -L ${chain} >/dev/null 2>&1; then
        current=$(${family} -t mangle -S ${chain} 2>/dev/null | sed -n '2,${
          toString (builtins.length specs + 1)
        }p')
        if [ "$current" != ${lib.escapeShellArg expected} ]; then
          # Remove any stray copies (defensive), then insert freshly in
          # reverse order so the list lands as slots 1..n.
      ${
        lib.concatMapStrings (r: ''
          while ${family} -t mangle -D ${chain} ${r} 2>/dev/null; do :; done
        '') specs
      }${
        lib.concatMapStrings (r: ''
          ${family} -t mangle -I ${chain} 1 ${r} 2>/dev/null || true
        '') (lib.reverseList specs)
      }    fi
      fi
    '';
in
{
  inherit description;
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
  script = ''
    while true; do
    ${lib.concatMapStrings ensure groups}
      sleep 1
    done
  '';
  preStop = lib.concatMapStrings (r: ''
    while ${r.family} -t mangle -D ${r.chain} ${r.rule} 2>/dev/null; do :; done
  '') rules;
}

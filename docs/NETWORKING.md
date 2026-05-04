# Networking Stack

DNS, Portmaster firewall, and Mullvad VPN interactions. Consolidates the
constraints captured across the security/hardware/networking modules so the
full picture lives in one place.

## DNS — everything is DoT-encrypted

Two DoT layers run in parallel. Both are always encrypted, independent of
Mullvad VPN state.

### 1. Application DNS — `systemd-resolved` → Mullvad DoT

- Apps resolve names via glibc → `/etc/resolv.conf` → `127.0.0.53`
  (`systemd-resolved` stub).
- `systemd-resolved` forwards to
  `194.242.2.3#dns.mullvad.net` (+ IPv6 equivalent) over **DoT on :853**.
- Cert validated via the SNI hostname pair.
- Configured by `myModules.hardware.networking.{nameservers,dnsOverTls}` in
  `parts/hardware/networking.nix`.

Verify on a live host:

```sh
resolvectl status | head
#   Global
#     Protocols: +DNSOverTLS …   ← the '+' means DoT is active
ss -tnp | grep :853
#   ESTAB … <local>:* <->  194.242.2.3:853  resolve
```

### 2. Portmaster-internal DNS — Portmaster → Mullvad DoT

Portmaster has its own DNS resolver for rule matching. It does **not**
intercept app-level :53 traffic (`filter/dnsQueryInterception = false`,
required to avoid a Mullvad-bootstrap deadlock — see
`feedback_portmaster_dns_deadlock.md`). Portmaster's own lookups go out over
the same Mullvad DoT endpoint, configured via `forceSettings` in the host
file:

```nix
myModules.security.portmaster.forceSettings = {
  "filter/dnsQueryInterception" = false;
  "dns/nameservers" = [ "dot://dns.mullvad.net?ip=194.242.2.3&name=MullvadAdblockDoT&blockedif=empty" ];
  "dns/noAssignedNameservers" = true;
};
```

`forceSettings` (vs plain `settings`) means Portmaster's `preStart` reapplies
these values on every boot. UI edits to them are reverted — breaks the chain
otherwise. See `feedback_portmaster_forcesettings_pattern.md`.

### What this does / doesn't protect

| Scenario                            | ISP sees                               | Mullvad sees         | Protected by  |
| ----------------------------------- | -------------------------------------- | -------------------- | ------------- |
| VPN off, app looks up `example.com` | TLS flow to `194.242.2.3:853` (opaque) | query + your real IP | DoT           |
| VPN on, app looks up `example.com`  | WireGuard packets to Mullvad exit      | query + VPN exit IP  | DoT inside WG |
| VPN off, Portmaster matches rule    | same TLS flow                          | query + your real IP | DoT           |

Mullvad's public DoT resolver is **free** and does not require a paid VPN
subscription; the paid VPN only covers the WireGuard tunnel. See
<https://mullvad.net/en/help/dns-over-https-and-dns-over-tls>.

Swap the resolver in `parts/hardware/networking.nix` if you'd rather use
Quad9 / Cloudflare / NextDNS — keep the `IP#hostname` form so DoT cert
validation still works.

## Portmaster ↔ Mullvad fwmark coexistence

Both use iptables/nftables. Mullvad's routing relies on fwmark `0x6d6f6c65`
on WireGuard traffic. Portmaster's `CONNMARK --restore-mark` rule clobbers
that mark, which silently kills routing inside the VPN tunnel.

`parts/security/portmaster-mullvad-compat.nix` inserts a `RETURN` rule ahead
of Portmaster's CONNMARK restore whenever `wg0-mullvad` is present. Watcher
systemd unit (`portmaster-mullvad-fwmark-preserve.service`) reapplies the
rule on interface bounces. See `feedback_portmaster_mullvad_fwmark.md` for
the incident trail.

Required on every host where both Portmaster and Mullvad run:

```nix
myModules.security.portmasterMullvadCompat.enable = true;
```

## Boot ordering

Portmaster must start **after** Mullvad's resolver can be reached, because
Portmaster queries its own `dns/nameservers` on startup. The Mullvad daemon
in turn needs network up. `services.mullvad-vpn` + `portmaster.service`
ordering is handled implicitly by systemd via `After=network-online.target`
on both.

If Portmaster starts before Mullvad is ready, you'll see Portmaster try to
DoT `194.242.2.3`, fail, fall back, then Mullvad finally comes up. The
`forceSettings` pattern means Portmaster re-reads config on every preStart,
so any UI-introduced drift is corrected before the bootstrap race.

## Related modules + rationale docs

- `parts/hardware/networking.nix` — systemd-resolved DoT + NetworkManager +
  firewall
- `parts/security/portmaster.nix` — Portmaster service + `forceSettings`
- `parts/security/portmaster-mullvad-compat.nix` — fwmark preservation
- `parts/services/mullvad.nix` — Mullvad VPN daemon
- `reference_portmaster_config_format.md` — key grammar for `config.json`
  overrides
- `feedback_portmaster_*.md` — incident-driven constraints

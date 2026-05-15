# Networking Stack

DNS, firewall, and VPN interaction constraints.

**See also:** [ARCHITECTURE.md](ARCHITECTURE.md) for module placement.

## DNS — DoT-encrypted with fallback

Two DNS layers run in parallel. Application DNS is opportunistic DoT
(strict would SERVFAIL during Mullvad tunnel transitions when the upstream
switches to plaintext 100.64.0.23). Portmaster's internal lookups are
strict DoT with Quad9 fallback.

### 1. Application DNS — `systemd-resolved` → Mullvad DoT (opportunistic)

- Apps resolve names via glibc → `/etc/resolv.conf` → `127.0.0.53`
  (`systemd-resolved` stub).
- `systemd-resolved` forwards to
  `194.242.2.3#dns.mullvad.net` (+ IPv6 equivalent) over **DoT on :853**.
- When Mullvad tunnel is up, Mullvad overrides the upstream to
  `100.64.0.23` (plaintext, in-tunnel). DoT mode is **opportunistic** so
  this plaintext upstream still works without SERVFAIL.
- Cert validated via the SNI hostname pair (when DoT is active).
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

Portmaster has its own DNS resolver for internal lookups (filter lists, app
reputation). It does **not** intercept app-level :53 traffic
(`filter/dnsQueryInterception = false`, required to avoid a Mullvad-bootstrap
deadlock — see `feedback_portmaster_dns_deadlock.md`). Application DNS flows
through systemd-resolved, not Portmaster.

Portmaster's internal resolver uses strict DoT with Quad9 fallback:

```nix
myModules.security.portmaster.forceSettings = {
  "filter/dnsQueryInterception" = false;
  "dns/nameservers" = [
    "dot://dns.mullvad.net?ip=194.242.2.3&name=MullvadAdblockDoT&blockedif=empty"
    "dot://dns.quad9.net?ip=9.9.9.9&name=Quad9&blockedif=empty"
    "dot://dns.quad9.net?ip=149.112.112.112&name=Quad9&blockedif=empty"
    "dot://dns.mullvad.net?ip=194.242.2.2&name=MullvadUnfilteredDoT&blockedif=empty"
  ];
  "dns/noAssignedNameservers" = true;
  "dns/noInsecureProtocols" = true;
  "spn/enable" = false;
};
```

`forceSettings` (vs plain `settings`) means Portmaster's `preStart` reapplies
these values on every boot. UI edits to them are reverted — breaks the chain
otherwise. See `feedback_portmaster_forcesettings_pattern.md`.

**Portmaster self-check failure:** Because `dnsQueryInterception = false`,
Portmaster's built-in connectivity self-check fails — it reports a
"Detected Compatibility Issue" notification. This is cosmetic and
unavoidable given the alternative is a DNS deadlock. Portmaster also loses
per-process DNS attribution (apps resolve via systemd-resolved, not
Portmaster's resolver).

### What this does / doesn't protect

| Scenario                            | ISP sees                               | Mullvad sees         | Protected by           |
| ----------------------------------- | -------------------------------------- | -------------------- | ---------------------- |
| VPN off, app looks up `example.com` | TLS flow to `194.242.2.3:853` (opaque) | query + your real IP | DoT (opportunistic)    |
| VPN on, app looks up `example.com`  | WireGuard packets to Mullvad exit      | query + VPN exit IP  | plaintext in-tunnel    |
| VPN on, tunnel transition           | WireGuard packets                      | N/A                  | opportunistic fallback |
| VPN off, Portmaster internal lookup | TLS flow to resolver                   | query + your real IP | DoT (strict)           |

**Note:** When the tunnel is up, Mullvad overrides systemd-resolved's
upstream to `100.64.0.23` (plaintext, in-tunnel). This is acceptable because
the entire tunnel is encrypted — the plaintext DNS is only visible inside
the WireGuard channel. Opportunistic DoT means resolved doesn't SERVFAIL
during the transition between tunnel-up and tunnel-down states.

Mullvad's public DoT resolver is **free** and does not require a paid VPN
subscription; the paid VPN only covers the WireGuard tunnel. See
<https://mullvad.net/en/help/dns-over-https-and-dns-over-tls>.

Quad9 (`9.9.9.9`, `149.112.112.112`) is configured as fallback in
Portmaster's internal resolver. If Mullvad's DoT is unreachable (e.g.
Mullvad infrastructure outage), Portmaster falls back to Quad9 DoT.

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

If Portmaster starts before Mullvad is ready, Portmaster tries
DoT `194.242.2.3`, fails, falls back, then Mullvad finally comes up. The
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

## Pixel 9 Pro — AVF VM Networking

The pixel runs NixOS inside an Android Virtualization Framework (AVF) VM.
The VM sits behind Android NAT (`10.255.231.x/24`) — outbound works,
inbound from the network is blocked.

### Why ADB ProxyCommand

The Android Terminal app's port forwarding binds to `127.0.0.1` on the
phone only (confirmed in AOSP source: `PortsStateManager.kt`). Direct
SSH from WiFi is not possible. The standard workaround is ADB as a
transport — `adb shell nc <vm-ip> 2222` reaches the VM directly,
bypassing the localhost-only forward.

The SSH ProxyCommand resolves the VM IP dynamically from the phone's
ARP table (`/proc/net/arp`, `avf_tap_fixed` interface) so it survives
DHCP reassignment. USB ADB is preferred by serial; wireless ADB is
auto-discovered via mDNS (`_adb-tls-connect._tcp`).

### Why Syncthing uses relay

The VM cannot be reached directly from the LAN (Android NAT). Syncthing
relay servers bridge both sides via outbound connections — no ADB needed.
`relaysEnabled` and `globalAnnounceEnabled` are set on all hosts that
peer with the pixel. All relay traffic is E2E encrypted (TLS 1.3);
relay servers see only ciphertext.

A udev rule auto-creates ADB port forwards on USB plug-in for direct
(faster) Syncthing when the phone is physically connected.

### VM lifecycle

Android's Low Memory Killer can SIGKILL the VM with no graceful
shutdown. Persistence settings on the phone (Doze exempt, unrestricted
battery, "Stay awake" when USB-connected) reduce but don't eliminate
this. The VM's NixOS config uses zram + disk swap + aggressive cache
pressure to stay within the 4 GB RAM ceiling.

### Deploying to the pixel

Syncthing syncs the working tree but not `.git/`. To deploy:

```sh
# rsync nix + site repos to pixel ($SITE_DIR = local site input path)
rsync -avz --delete --exclude='.git' --exclude='.direnv' --exclude='repos/' \
  --exclude='.claude/' --exclude='.gemini/' --exclude='.codex/' \
  -e 'ssh pixel-9-pro' ~/Documents/nix/ droid@pixel-9-pro:~/Documents/nix/

rsync -avz --delete --exclude='.git' \
  -e 'ssh pixel-9-pro' "$SITE_DIR/" droid@pixel-9-pro:~/Documents/"$(basename "$SITE_DIR")"/

# rebuild on pixel
ssh pixel-9-pro 'sudo nixos-rebuild switch \
  --flake "path:$HOME/Documents/nix#pixel-9-pro" \
  --override-input site "path:$HOME/Documents/'"$(basename "$SITE_DIR")"'"'
```

The pixel has its own `.git/` (initialized separately, tracking
`origin/main`). After the git repo is set up, `nrb` works natively
on the pixel — it detects the `path:` scheme and site input override
automatically.

### Related modules

- `parts/hosts/pixel-9-pro/` — NixOS host config (SSH, firewall, AVF overrides)
- `home/hosts/pixel-9-pro/` — HM config (lean CLI toolset)
- `parts/services/syncthing.nix` — `relaysEnabled` / `globalAnnounceEnabled` options
- `site/hosts/pixel-9-pro.nix` — ADB serial, USB product IDs (private)

---

_Last verified: 2026-05-15._

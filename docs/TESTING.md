# Testing

VM integration tests and how to run them.

**See also:** [BUILD.md](BUILD.md) for the full check/hook matrix.

## Automated Tests

46 checks total. See `docs/BUILD.md` for the full matrix.

```bash
# Fast eval-only (~10s) — daily use, MacBook, slow machines:
nrb --check
nix flake check --no-build

# Single VM test (~3-7min each):
nix build --no-link '.#checks.x86_64-linux.vm-core'

# All eval canaries (~30s):
nix build --no-link '.#checks.x86_64-linux.eval-'{kernel-cachyos,boot-lanzaboote,security-hardening,services-earlyoom}

# Full suite including 10 VM tests (~10-20min cached, ~60min cold):
nix flake check
```

### VM Test Inventory

Each test boots a QEMU VM with KVM acceleration and runs assertions.

| Test                       | Modules tested                        | Asserts                                                         |
| -------------------------- | ------------------------------------- | --------------------------------------------------------------- |
| `vm-core`                  | nix-nix, users                        | Nix daemon + flakes + cgroups + user creation + groups + zsh    |
| `vm-ssh`                   | security-ssh, users                   | sshd hardening, fail2ban, firewall port 22                      |
| `vm-networking`            | hardware-networking, users            | NetworkManager + systemd-resolved + DNS-over-TLS                |
| `vm-hardware-pipewire`     | hardware-pipewire, users              | PipeWire + LADSPA filter chain config                           |
| `vm-security-agenix`       | security-agenix, users                | agenix + age CLI availability                                   |
| `vm-boot-impermanence`     | boot-impermanence, users              | /persist bind mount via findmnt                                 |
| `vm-nrb-build-fail-timing` | (standalone)                          | nrb returns within 30s on build failure (no sudo keepalive hang) |
| `vm-nrb-preflight-no-daemon` | (standalone)                        | nrb detects stopped nix daemon cleanly                          |
| `smoke-v2`                 | host, users, networking, syncthing    | v2-tier (MBP): multi-user + NM + Syncthing                     |
| `smoke-v4`                 | host, users, networking, syncthing    | v4-tier (Ryzen): multi-user + NM + Syncthing                   |

## Manual Test Checklists

These modules require real hardware, network, or desktop sessions that
cannot be reproduced in a VM.

### Portmaster + Mullvad Stack

Run after any change to `parts/security/portmaster*.nix`,
`parts/services/mullvad.nix`, or `parts/hardware/networking.nix`:

1. `mullvad status` → Connected
2. `sudo iptables -t mangle -S PORTMASTER-INGEST-OUTPUT | head -1` → contains `0x6d6f6c65`
3. Browse any site → works
4. `resolvectl status | grep DNSOverTLS` → shows `opportunistic`
5. `mullvad disconnect` → browse any site → still works (Quad9 fallback)
6. `mullvad connect` → browse → works within 5s
7. Portmaster UI → Settings → check "Detected Compatibility Issue" notification present (expected, cosmetic)

### PipeWire + DeepFilterNet Denoise

Run after any change to `parts/hardware/pipewire.nix` or
`home/modules/goxlr/denoise.nix`:

1. `systemctl --user status pipewire` → active
2. `journalctl --user -u pipewire --since -5m | grep -i "error\|fail"` → empty
3. `wpctl status` → shows filter-chain nodes (DeepFilter)
4. GoXLR mic input → speak → verify noise reduction active in `wpctl status` graph
5. No crackling/artifacts at idle

### Impermanence

Run after any change to `parts/boot/impermanence.nix`:

1. Reboot
2. `ls /persist/` → expected directories present
3. Create file in `/tmp/test-ephem` → reboot → file gone
4. Verify `/etc/machine-id` persists across reboots

### Kernel (CachyOS + LTO)

Run after `nix flake update cachyos-kernel`:

1. `uname -r` → contains `cachyos` or `lto`
2. `dmesg | grep -i "kernel\|bore\|bpf"` → no errors
3. `cat /proc/version` → matches expected

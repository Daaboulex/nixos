# Testing

Automated VM tests and manual test checklists for modules that cannot be
fully tested in a NixOS VM.

## Automated Tests

Run all checks with `nix flake check`. See `docs/BUILD.md` for the full
check matrix (18 checks). Individual tests:

```bash
nix build .#checks.x86_64-linux.vm-hardware-pipewire
nix build .#checks.x86_64-linux.vm-networking-resolved
nix build .#checks.x86_64-linux.eval-kernel-cachyos
```

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

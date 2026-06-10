#!/usr/bin/env bash
# vfio-deep-verify — empirical verification of the VFIO static-binding refactor.
# Run on ryzen-9950x3d (has the real site + IFD cache). Read-only except the
# protected-disk guard, which only reads sysfs/findmnt. Does NOT start any VM.
set -uo pipefail
cd /home/user/Documents/nix || exit 1
git add -A 2>/dev/null || true
# Array (not a string) so the three flags word-split correctly under "${O[@]}"
# without tripping SC2086 — `nix eval` needs them as separate argv entries.
O=(--override-input site "path:./repos/site")
B=".#nixosConfigurations.ryzen-9950x3d.config"

echo "########## 1. GENERATED HOOK SHELL (vfio-amd, the real interpolated output) ##########"
hp=$(nix eval --raw "${O[@]}" "$B.specialisation.vfio-amd.configuration.environment.etc.\"libvirt/hooks/qemu\".source" 2>/dev/null)
echo ">> $hp"
nl -ba "$hp" 2>/dev/null | sed -n '1,160p'

echo
echo "########## 2. PROTECTED-DISK GUARD — LIVE empirical test ##########"
# Source the hook with non-matching args (HOOK_NAME=noop) so NO section runs,
# only the functions get defined; then call the guard directly. Read-only.
(
  set +eu
  # shellcheck disable=SC1090
  source "$hp" audit noop noop 2>/dev/null
  # shellcheck disable=SC2034 # read by the sourced hook's log() as a global
  GUEST_NAME=audit
  if vfio_guard_protected_disk 0000:04:00.0; then echo "04:00.0 (host LUKS root) => REFUSED  [CORRECT]"; else echo "04:00.0 (host LUKS root) => ALLOWED  [*** WRONG ***]"; fi
  if vfio_guard_protected_disk 0000:0f:00.0; then echo "0f:00.0 (Windows 2TB)    => REFUSED  [check: should be ALLOWED]"; else echo "0f:00.0 (Windows 2TB)    => ALLOWED  [CORRECT]"; fi
  if vfio_guard_protected_disk 0000:0b:00.0; then echo "0b:00.0 (1TB nvidia)     => REFUSED  [check]"; else echo "0b:00.0 (1TB nvidia)     => ALLOWED  [CORRECT]"; fi
)

echo
echo "########## 3. GENERATED DOMAIN XML (win11-amd) — managed=/hostdev/stealth ##########"
dx=$(nix eval --raw "${O[@]}" "$B.specialisation.vfio-amd.configuration.virtualisation.libvirt.connections.\"qemu:///system\".domains" --apply 'ds: (builtins.head ds).definition' 2>/dev/null)
echo ">> $dx"
if [ -f "$dx" ]; then
  echo "-- hostdev managed= lines --"
  grep -niE "hostdev|managed=" "$dx" | head -25
  echo "-- stealth/faithfulness markers --"
  grep -ciE "hyperv|smbios|sysinfo|vendor_id|AuthAMD" "$dx" | sed 's/^/hyperv+smbios marker count: /'
else echo "(definition is not a file path: '$dx')"; fi

echo
echo "########## 4. PROJECT GATES (pre-commit on changed files) ##########"
nix develop -c pre-commit run --files \
  parts/vfio/_lib.nix parts/vfio/device-binding.nix parts/vfio/vms.nix \
  parts/hosts/ryzen-9950x3d/default.nix 2>&1 | tail -40

echo
echo "########## DONE ##########"

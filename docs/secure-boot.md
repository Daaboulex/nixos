# Secure Boot with Lanzaboote

NixOS does not natively support Secure Boot. [Lanzaboote](https://github.com/nix-community/lanzaboote) bridges this gap by replacing `systemd-boot` with a signed UEFI stub that chainloads NixOS generations.

This guide covers initial setup, how the NixOS module works, and recovery after BIOS updates.

## How It Works

### Architecture

```
UEFI Firmware (Secure Boot ON)
  └── Lanzaboote stub (signed EFI binary)
        └── Unified Kernel Image (signed)
              └── initrd → NixOS system
```

1. **sbctl** generates your own Secure Boot keys (PK, KEK, db) and stores them at `/var/lib/sbctl`
2. **Lanzaboote** hooks into `nixos-rebuild` and signs all EFI binaries (bootloader + kernel images) with your keys
3. The UEFI firmware verifies signatures on boot — only your signed binaries can execute

### NixOS Module (`parts/system/boot.nix`)

The flake integrates Lanzaboote via:

```nix
# Host flake-module.nix imports:
inputs.lanzaboote.nixosModules.lanzaboote

# Host default.nix enables:
myModules.system.boot = {
  enable = true;
  loader = "systemd-boot";
  secureBoot.enable = true;    # Activates Lanzaboote
  plymouth.enable = true;       # Works with Secure Boot
};
```

When `secureBoot.enable = true`:
- `boot.lanzaboote.enable` is set, replacing raw `systemd-boot`
- `boot.lanzaboote.pkiBundle` points to `/var/lib/sbctl` (configurable via `secureBoot.pkiBundle`)
- `sbctl` is added to system packages for key management
- `systemd-boot.enable` is automatically disabled (Lanzaboote takes over)

## Initial Setup (New System)

Secure Boot key creation cannot be automated by Nix because it requires writing to UEFI firmware variables, which is a one-time hardware operation.

### Prerequisites

- UEFI firmware (not legacy BIOS)
- Secure Boot set to **Setup Mode** in BIOS (usually: disable Secure Boot → clear keys → it enters Setup Mode)
- A working NixOS installation with this flake applied

### Step 1: Verify Setup Mode

```bash
sudo sbctl status
```

You should see:
```
Installed:      ✓ sbctl is installed
Owner GUID:     <none>
Setup Mode:     ✓ Enabled    ← Required
Secure Boot:    ✗ Disabled
```

If Setup Mode shows `✗ Disabled`, you need to enter BIOS and clear the Secure Boot keys first.

### Step 2: Create Your Keys

```bash
sudo sbctl create-keys
```

This generates:
- `/var/lib/sbctl/keys/PK/` — Platform Key (root of trust)
- `/var/lib/sbctl/keys/KEK/` — Key Exchange Key
- `/var/lib/sbctl/keys/db/` — Signature Database key (signs binaries)
- `/var/lib/sbctl/GUID` — Your unique Owner GUID

### Step 3: Enroll Keys into Firmware

```bash
sudo sbctl enroll-keys --microsoft
```

The `--microsoft` flag includes Microsoft's keys alongside yours. This is **required** for:
- GPU firmware (VBIOS) to load — most GPUs have Microsoft-signed Option ROMs
- USB device firmware during early boot
- Any third-party UEFI drivers

Without `--microsoft`, your system may not POST or display video output.

> **Troubleshooting**: If you get an error about "immutable files":
> ```bash
> sudo chattr -i /sys/firmware/efi/efivars/PK-*
> sudo chattr -i /sys/firmware/efi/efivars/KEK-*
> sudo chattr -i /sys/firmware/efi/efivars/db-*
> sudo sbctl enroll-keys --microsoft
> ```

### Step 4: Rebuild to Sign Binaries

```bash
nrb
```

Or manually:
```bash
sudo nixos-rebuild switch --flake ".#<hostname>"
```

Lanzaboote signs during activation:
```
Installing Lanzaboote to "/boot"...
Collecting garbage...
Successfully installed Lanzaboote.
```

### Step 5: Verify Signatures

```bash
sudo sbctl verify
```

Expected output (all green):
```
✓ /boot/EFI/BOOT/BOOTX64.EFI is signed
✓ /boot/EFI/systemd/systemd-bootx64.efi is signed
✓ /boot/EFI/Linux/nixos-generation-*.efi is signed
```

### Step 6: Enable Secure Boot in BIOS

1. Reboot and enter BIOS/UEFI
2. Navigate to **Boot** or **Security** section
3. Set **Secure Boot** to **Enabled** (on ASUS boards: "Windows UEFI mode")
4. Save and exit

### Step 7: Final Verification

After booting into NixOS:

```bash
sudo sbctl status
```

Expected:
```
Installed:      ✓ sbctl is installed
Owner GUID:     <your-guid>
Setup Mode:     ✗ Disabled
Secure Boot:    ✓ Enabled
Vendor Keys:    microsoft
```

You can also verify via the kernel:
```bash
bootctl status | grep "Secure Boot"
```

## Recovery After BIOS Update

BIOS updates typically wipe Secure Boot variables (PK, KEK, db, dbx), putting the motherboard back into Setup Mode. Your keys still exist at `/var/lib/sbctl` — they just need to be re-enrolled.

### Step 1: Check Status

```bash
sudo sbctl status
```

You should see:
- `Owner GUID`: (your existing GUID — keys are intact)
- `Setup Mode`: ✓ Enabled (firmware was wiped)
- `Secure Boot`: ✗ Disabled

### Step 2: Re-enroll Keys

```bash
sudo sbctl enroll-keys --microsoft
```

### Step 3: Rebuild

```bash
nrb
```

This re-signs all boot binaries.

### Step 4: Verify and Enable

```bash
sudo sbctl verify
```

Then reboot into BIOS and re-enable Secure Boot (Step 6 from initial setup).

### Step 5: Confirm

```bash
sudo sbctl status
```

Should show `Secure Boot: ✓ Enabled` again.

## Backing Up Keys

Your Secure Boot keys at `/var/lib/sbctl` are **not managed by Nix** and not in your flake. If you lose them, you must create new keys and re-enroll.

Back them up:
```bash
sudo tar -czf sbctl-keys-backup.tar.gz -C /var/lib sbctl
# Store securely (encrypted drive, password manager, etc.)
```

Restore on a new install:
```bash
sudo tar -xzf sbctl-keys-backup.tar.gz -C /var/lib
sudo sbctl enroll-keys --microsoft
nrb
```

## Troubleshooting

### System won't POST after enrolling keys

You likely enrolled without `--microsoft`. Boot from a USB, mount your system, and:
```bash
sudo chattr -i /sys/firmware/efi/efivars/{PK,KEK,db}-*
sudo sbctl enroll-keys --microsoft
```

Or clear Secure Boot keys in BIOS to get back to Setup Mode.

### `sbctl verify` shows unsigned files

Old generations may have unsigned kernels. Lanzaboote boots unified images, so these are harmless. To clean up:
```bash
# Remove old generations
sudo nix-collect-garbage -d
# Rebuild to update boot entries
nrb
sudo sbctl verify
```

### Secure Boot is enabled but `sbctl status` shows disabled

Check if your BIOS has separate "Secure Boot" and "Secure Boot Mode" settings. Some boards require setting the mode to "Custom" or "Standard" after enabling.

### Plymouth not showing with Secure Boot

Plymouth requires early KMS. Ensure your GPU driver is in the initrd:
```nix
# This flake handles it automatically when both are enabled:
myModules.system.boot.plymouth.enable = true;
myModules.hardware.graphics.amd.enable = true;  # Loads amdgpu in initrd
```

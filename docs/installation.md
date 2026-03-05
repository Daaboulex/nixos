# NixOS Installation Guide

Complete guide for installing NixOS using this flake's automated installer. The installer creates a BTRFS filesystem with optional LUKS encryption, generates hardware configuration, and runs `nixos-install` with your chosen host config.

## Prerequisites

- A **NixOS live USB** booted on the target machine (any recent NixOS ISO works)
- The machine must be booted in **UEFI mode** (the installer creates GPT + EFI System Partition)
- **Network connectivity** (the build downloads packages from cache.nixos.org)
- Know which disk you want to install to and which host config to use

### Available Host Configurations

| Hostname | Hardware | Kernel Variants |
|----------|----------|----------------|
| `ryzen-9950x3d` | Zen 5 desktop, RDNA 4 GPU, 64GB RAM | CachyOS-LTO (single config) |
| `macbook-pro-9-2` | 2012 MacBook Pro, Ivy Bridge i5, Intel HD4000, 16GB RAM | Default + xanmod + cachyos (specialisations) |

Hosts with specialisations build **all kernel variants** in a single install. Each variant appears as a separate entry in the systemd-boot menu.

---

## Step 1: Create the Live USB

### Download the ISO

This flake tracks `nixos-unstable`, so use the **unstable graphical ISO** for best compatibility:

```
https://channels.nixos.org/nixos-unstable/latest-nixos-graphical-x86_64-linux.iso
```

The graphical ISO includes NetworkManager (easier WiFi), a desktop environment for troubleshooting, and a terminal. The minimal ISO also works but requires `wpa_supplicant` for WiFi.

### Flash to USB

**Linux:**

```bash
# Find your USB device (check SIZE and MODEL carefully!)
lsblk

# Flash (replace /dev/sdX with your USB — NOT your main disk!)
sudo dd if=nixos-graphical-*-x86_64-linux.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

**Alternative tools:** [Ventoy](https://www.ventoy.net/) (multi-ISO USB), [Etcher](https://etcher.balena.io/), or [GNOME Disks](https://apps.gnome.org/DiskUtility/) (Restore Disk Image).

### Boot from USB

1. Plug the USB into the target machine
2. Enter BIOS/boot menu (usually F2, F12, Del, or Option on Mac)
3. Select the USB drive (UEFI mode, not Legacy/CSM)
4. **Verify UEFI mode** after boot: `ls /sys/firmware/efi` (should list files, not "No such file")

## Step 2: Connect to the Network

### Ethernet (automatic)

If you have a wired connection, it should work immediately:

```bash
ping -c2 nixos.org
```

### WiFi

**Option A: Using wpa_supplicant** (available on minimal ISO)

```bash
sudo systemctl start wpa_supplicant
wpa_cli
```

Inside `wpa_cli`:

```
> scan
> scan_results
> add_network
> set_network 0 ssid "YourNetworkName"
> set_network 0 psk "YourPassword"
> enable_network 0
> quit
```

Wait a few seconds, then verify:

```bash
ping -c2 nixos.org
```

**Option B: Using NetworkManager** (available on graphical ISO)

```bash
nmcli device wifi connect "YourNetworkName" password "YourPassword"
```

### MacBook Pro 9,2 WiFi Note

The Broadcom BCM4331 chip in the 2012 MacBook may not work out of the box on the live USB. Options:

- Use a **USB Ethernet adapter** or **USB WiFi dongle** (recommended)
- Use phone USB tethering (plug in phone, enable USB tethering)
- If `b43` driver loads, WiFi may work with `wpa_supplicant` above

## Step 3: Clone the Repository

```bash
# Enable Nix flakes on the live USB
export NIX_CONFIG="experimental-features = nix-command flakes"

# Get git (not always on minimal ISO)
nix-shell -p git

# Clone the repo
git clone https://github.com/YOUR_USER/YOUR_REPO.git ~/nix
cd ~/nix
```

Replace the URL with your actual repository.

## Step 4: Identify Your Target Disk

Run the installer without arguments to see all disks:

```bash
sudo bash scripts/install-btrfs.sh
```

Output example:

```
========== ALL DISKS AND THEIR CONTENTS ==========

NAME   SIZE  TYPE FSTYPE LABEL     MODEL
sda    250G  disk                   Samsung SSD 850 EVO 250GB
+-sda1 100M  part vfat   EFI
+-sda2 150G  part ntfs   Windows
+-sda3  99G  part ext4   old-linux
sdb    250G  disk                   APPLE SSD SM0256F
+-sdb1 250G  part ext4   nixos
```

**Read this carefully.** Identify each disk by its **MODEL** and **SIZE**. Decide which disk to install NixOS on. The other disk will not be touched.

**Multi-disk safety:** If you have multiple SSDs (like the MacBook Pro with 2x 250GB), the script shows both disks, their models, serial numbers, and current contents. It requires you to type the full device path (`/dev/sdb`) to confirm — you cannot accidentally wipe the wrong disk.

## Step 5: Run the Installer

### Basic Usage

```bash
sudo bash scripts/install-btrfs.sh /dev/sdX <hostname>
```

Replace `/dev/sdX` with your target disk and `<hostname>` with your host config name.

### Common Examples

```bash
# MacBook with encryption + 4GB swap (recommended for 16GB RAM laptop)
sudo bash scripts/install-btrfs.sh --swap 4G /dev/sdb macbook-pro-9-2

# Desktop with encryption, no swap (64GB RAM, ZRAM handles it)
sudo bash scripts/install-btrfs.sh /dev/nvme0n1 ryzen-9950x3d

# MacBook without encryption (faster boot, less secure)
sudo bash scripts/install-btrfs.sh --no-encrypt --swap 4G /dev/sdb macbook-pro-9-2

# Partition only — review before installing
sudo bash scripts/install-btrfs.sh --no-install --swap 4G /dev/sdb macbook-pro-9-2
```

### All Options

| Option | Description |
|--------|-------------|
| `--swap <size>` | Create a swap partition. Accepts `4G`, `2048M`, or `4` (assumes GiB) |
| `--no-encrypt` | Skip LUKS encryption (no passphrase at boot) |
| `--no-install` | Partition and mount only, skip `nixos-install` |
| `--flake <path>` | Override flake directory (default: auto-detected from script location) |
| `-h` / `--help` | Show usage |

### What the Script Does

The installer runs through these phases:

**Phase 1: Validation**
- Verifies root permissions
- Resolves symlinks (`/dev/disk/by-id/...` works)
- Checks UEFI boot mode (warns if legacy BIOS)
- Validates swap size format
- Locates the flake directory and host config
- Checks disk is at least 20 GB

**Phase 2: Safety Confirmation**
- Displays ALL disks with model, serial, size, and current contents
- Shows the target disk's existing partitions
- Shows all OTHER disks (marked "will NOT be touched")
- Displays the full installation plan (partition layout, encryption, subvolumes)
- **Confirmation 1:** You must type the full device path (e.g., `/dev/sdb`)
- **Confirmation 2:** If the disk has existing OS partitions, you must type `ERASE`

**Phase 3: Partitioning**
- Creates GPT partition table
- Partition 1: 512 MB EFI System Partition (FAT32, labeled `BOOT`)
- Partition 2 (if `--swap`): Swap partition (optionally LUKS encrypted)
- Partition 3 (or 2): Root partition (optionally LUKS encrypted)
- Waits for partition devices to appear (handles slow USB drives)

**Phase 4: Encryption (unless `--no-encrypt`)**
- Formats swap partition with LUKS2 (if swap enabled) — prompts for passphrase
- Formats root partition with LUKS2 — prompts for passphrase
- Tip: use the **same passphrase** for both — systemd unlocks both with a single prompt at boot

**Phase 5: Filesystem**
- Creates BTRFS on the root partition (or LUKS device) with zstd compression
- Creates subvolumes:

| Subvolume | Mount Point | Purpose |
|-----------|-------------|---------|
| `@` | `/` | Root filesystem |
| `@home` | `/home` | User data |
| `@nix` | `/nix` | Nix store (largest, benefits from compression) |
| `@log` | `/var/log` | System logs (separate for rollback safety) |
| `@cache` | `/var/cache` | Package caches |
| `@tmp` | `/tmp` | Temporary files |
| `@snapshots` | `/.snapshots` | BTRFS snapshots |

- Mounts all subvolumes with `compress=zstd,noatime`
- SSDs automatically get `ssd,discard=async` mount options

**Phase 6: Hardware Detection**
- Runs `nixos-generate-config --root /mnt` to detect hardware
- Copies the generated `hardware-configuration.nix` into the flake's host directory
- This file contains your disk UUIDs, detected kernel modules, and filesystem mounts

**Phase 7: NixOS Installation (unless `--no-install`)**
- Enables Nix experimental features (flakes work on the live USB)
- Runs `nixos-install --flake <path>#<hostname> --no-root-passwd`
- Downloads and builds the full system (this takes a while on slower hardware)

**Phase 8: Cleanup**
- If anything fails after partitioning, a cleanup trap automatically:
  - Unmounts `/mnt` and all submounts
  - Closes LUKS devices (`cryptroot`, `cryptswap`)
- You can safely re-run the script after a failure

## Step 6: Set User Password

After the install completes:

```bash
sudo nixos-enter --root /mnt -c 'passwd user'
```

Replace `user` with your actual username (check `parts/system/users.nix` for the `primaryUser` default).

## Step 7: Reboot

```bash
reboot
```

Remove the USB drive when prompted (or during BIOS splash).

### Boot Menu

On first boot, systemd-boot shows your available entries:

- **NixOS** — your default kernel
- **NixOS (xanmod)** — xanmod specialisation (if the host has one)
- **NixOS (cachyos)** — CachyOS specialisation (if the host has one)

Select the default entry. If it fails to boot, select another variant from the menu — all variants are built during install.

## Step 8: Post-Install Setup

### Verify the System

```bash
# Check system info (hostname, kernel, generation, specialisations)
nrb-info

# List all available configurations
nrb --list

# Verify all configs evaluate correctly
nrb --check
```

### Set Up Secrets (sops-nix)

If your configuration uses sops-nix for encrypted secrets:

**Option A: Generate a new age key on this machine**

```bash
sudo mkdir -p /var/lib/sops-nix
sudo age-keygen -o /var/lib/sops-nix/key.txt
```

Note the public key printed by `age-keygen`. You'll need to add it to `.sops.yaml` in the repo.

**Option B: Copy an existing age key from a backup**

```bash
sudo mkdir -p /var/lib/sops-nix
sudo cp /path/to/backup/key.txt /var/lib/sops-nix/key.txt
```

Then update `secrets/secrets.yaml` with the public key and rebuild:

```bash
nrb
```

### Set Up Secure Boot (if configured)

If your host config enables Lanzaboote (Secure Boot):

```bash
sudo sbctl create-keys
sudo sbctl enroll-keys --microsoft
nrb
```

See [secure-boot.md](secure-boot.md) for the full guide.

---

## Troubleshooting

### WiFi not working on live USB

Use USB Ethernet, USB WiFi dongle, or phone USB tethering. The live ISO may not have proprietary firmware for all WiFi chips.

### "experimental Nix feature 'flakes' is disabled"

The install script sets this automatically. If you're running commands manually:

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

### Build fails with download errors

Check network connectivity. If using Portmaster on another system, some CDN domains may be blocked. Try:

```bash
ping cache.nixos.org
nix-shell -p curl -- curl -I https://cache.nixos.org
```

### "Partition did not appear after 15 seconds"

Slow USB drive or kernel delay. Try manually:

```bash
partprobe /dev/sdX
ls /dev/sdX*
```

Then re-run the script.

### Script failed mid-way

The cleanup trap handles unmounting and closing LUKS. Just re-run the same command:

```bash
sudo bash scripts/install-btrfs.sh --swap 4G /dev/sdX <hostname>
```

### Need to manually mount an existing install

If you need to access the installed system from the live USB:

```bash
# Open LUKS (skip if --no-encrypt was used)
sudo cryptsetup open /dev/sdX2 cryptroot   # or sdX3 if swap exists

# Mount subvolumes
BTRFS_DEV=/dev/mapper/cryptroot   # or /dev/sdX2 if unencrypted
sudo mount -o subvol=@,compress=zstd,noatime "$BTRFS_DEV" /mnt
sudo mount -o subvol=@home,compress=zstd,noatime "$BTRFS_DEV" /mnt/home
sudo mount -o subvol=@nix,compress=zstd,noatime "$BTRFS_DEV" /mnt/nix
sudo mount /dev/sdX1 /mnt/boot

# Enter the system
sudo nixos-enter --root /mnt
```

Adjust partition numbers based on your layout (check `lsblk`).

### Wrong disk selected

The script requires typing the full device path AND typing `ERASE` if the disk has existing partitions. If you reach the "POINT OF NO RETURN" prompt and realize it's wrong, press Ctrl+C — nothing has been written yet.

### Build takes very long

First builds download and compile everything. On a MacBook Pro 9,2 (2C/4T Ivy Bridge), expect 30-60 minutes for a full build. Subsequent rebuilds (`nrb`) are much faster (only changed packages rebuild).

### "Host directory not found"

The hostname you passed doesn't match a directory in `parts/hosts/`. Check available hosts:

```bash
ls parts/hosts/
```

### Kernel panic on first boot

Select a different specialisation from the boot menu (xanmod or cachyos). Then investigate the default kernel issue after booting successfully. Use `nrb --dry` to test changes before switching.

---

## Partition Layout Reference

### With encryption + swap (`--swap 4G`)

```
/dev/sdX
+-sdX1   512M   FAT32    EFI System Partition (BOOT)
+-sdX2   4G     LUKS2    Encrypted swap
| +-cryptswap   swap
+-sdX3   rest   LUKS2    Encrypted BTRFS root
  +-cryptroot   btrfs
    +-@           /
    +-@home       /home
    +-@nix        /nix
    +-@log        /var/log
    +-@cache      /var/cache
    +-@tmp        /tmp
    +-@snapshots  /.snapshots
```

### With encryption, no swap

```
/dev/sdX
+-sdX1   512M   FAT32    EFI System Partition (BOOT)
+-sdX2   rest   LUKS2    Encrypted BTRFS root
  +-cryptroot   btrfs
    +-@           /
    +-@home       /home
    +-@nix        /nix
    +-@log        /var/log
    +-@cache      /var/cache
    +-@tmp        /tmp
    +-@snapshots  /.snapshots
```

### Without encryption (`--no-encrypt --swap 4G`)

```
/dev/sdX
+-sdX1   512M   FAT32    EFI System Partition (BOOT)
+-sdX2   4G     swap     Swap
+-sdX3   rest   btrfs    BTRFS root (nixos)
  +-@           /
  +-@home       /home
  +-@nix        /nix
  +-@log        /var/log
  +-@cache      /var/cache
  +-@tmp        /tmp
  +-@snapshots  /.snapshots
```

### NVMe drives

Same layouts, but partition names use the `p` separator:

```
/dev/nvme0n1
+-nvme0n1p1   512M   FAT32   EFI
+-nvme0n1p2   rest   LUKS2   Root
```

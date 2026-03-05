#!/usr/bin/env bash
# ============================================================================
# NixOS BTRFS Installation Script
# ============================================================================
# Run from a NixOS live USB. Partitions a disk with optional LUKS encryption
# and BTRFS subvolumes, generates hardware config, and installs NixOS.
#
# Usage: sudo bash install-btrfs.sh [options] /dev/sdX <hostname>
#
# Options:
#   --no-encrypt     Skip LUKS encryption
#   --swap <size>    Create a swap partition (e.g. --swap 4G, --swap 2048M)
#   --flake <path>   Path to flake directory (default: auto-detect)
#   --no-install     Partition and mount only, skip nixos-install
#
# Requires: UEFI boot mode (GPT + ESP partition layout)
#
# SAFETY: The script shows ALL disks with their contents and requires
# multiple confirmations before writing anything. It will NOT touch
# any disk other than the one you explicitly select.
# ============================================================================
set -euo pipefail

# ── Cleanup trap — runs on any exit after point of no return ──
PAST_POINT_OF_NO_RETURN=false
cleanup() {
  local exit_code=$?
  if [ $exit_code -ne 0 ] && $PAST_POINT_OF_NO_RETURN; then
    echo ""
    echo ">> Script failed (exit code $exit_code). Cleaning up..."
    umount /mnt/boot 2>/dev/null || true
    umount -R /mnt 2>/dev/null || true
    cryptsetup close cryptswap 2>/dev/null || true
    cryptsetup close cryptroot 2>/dev/null || true
    echo ">> Cleanup complete. You can safely re-run the script."
  fi
}
trap cleanup EXIT

# ── Parse swap size to MiB ──
parse_swap_mib() {
  local size="$1"
  if [[ "$size" =~ ^([0-9]+)[Gg]$ ]]; then
    echo "$(( BASH_REMATCH[1] * 1024 ))"
  elif [[ "$size" =~ ^([0-9]+)[Mm]$ ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$size" =~ ^([0-9]+)$ ]]; then
    # No suffix — assume GiB
    echo "$(( size * 1024 ))"
  else
    echo "ERROR: Invalid swap size '$size'. Use format: 4G, 2048M, or 4" >&2
    return 1
  fi
}

# ── Parse arguments ──
ENCRYPT=true
SWAP_SIZE=""
FLAKE_PATH=""
DO_INSTALL=true
DISK=""
HOSTNAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-encrypt)  ENCRYPT=false; shift ;;
    --swap)        SWAP_SIZE="$2"; shift 2 ;;
    --flake)       FLAKE_PATH="$2"; shift 2 ;;
    --no-install)  DO_INSTALL=false; shift ;;
    -h|--help)
      echo "Usage: sudo bash $0 [options] /dev/sdX <hostname>"
      echo ""
      echo "Options:"
      echo "  --no-encrypt     Skip LUKS encryption"
      echo "  --swap <size>    Create a swap partition (e.g. --swap 4G, --swap 2048M)"
      echo "  --flake <path>   Path to flake directory (default: auto-detect)"
      echo "  --no-install     Partition and mount only, skip nixos-install"
      echo ""
      echo "Requires UEFI boot mode (creates GPT + EFI System Partition)."
      echo "The host config must use systemd-boot or Lanzaboote."
      exit 0
      ;;
    /dev/*)        DISK="$1"; shift ;;
    *)             HOSTNAME="$1"; shift ;;
  esac
done

# ── Show all disks if no arguments ──
if [ -z "$DISK" ] || [ -z "$HOSTNAME" ]; then
  echo "Usage: sudo bash $0 [options] /dev/sdX <hostname>"
  echo ""
  echo "========== ALL DISKS AND THEIR CONTENTS =========="
  echo ""
  lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT,MODEL -e 7 2>/dev/null || \
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT -e 7
  echo ""
  echo "==================================================="
  echo ""
  echo "Identify your target disk by its MODEL and SIZE above."
  echo "Make SURE you pick the right one — the other disk will be untouched."
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: Must run as root (sudo)"
  exit 1
fi

# Resolve symlinks (supports /dev/disk/by-id/*, /dev/disk/by-path/*, etc.)
DISK="$(readlink -f "$DISK")"

if [ ! -b "$DISK" ]; then
  echo "ERROR: $DISK is not a block device"
  exit 1
fi

# ── UEFI check ──
if [ ! -d /sys/firmware/efi ]; then
  echo "WARNING: System is NOT booted in UEFI mode."
  echo "This script creates a GPT + EFI partition layout that requires UEFI."
  echo "If your target system uses legacy BIOS, this layout will not boot."
  echo ""
  read -p "Continue anyway? (y/N): " confirm_bios
  if [ "$confirm_bios" != "y" ] && [ "$confirm_bios" != "Y" ]; then
    echo "Aborted."
    exit 1
  fi
fi

# ── Validate swap size early ──
SWAP_SIZE_MIB=""
if [ -n "$SWAP_SIZE" ]; then
  SWAP_SIZE_MIB=$(parse_swap_mib "$SWAP_SIZE") || exit 1
fi

# ── Auto-detect flake path if not specified ──
if [ -z "$FLAKE_PATH" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  if [ -f "$SCRIPT_DIR/../flake.nix" ]; then
    FLAKE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
  else
    echo "ERROR: Cannot auto-detect flake path."
    echo "  Looked for: $SCRIPT_DIR/../flake.nix"
    echo "  Use: --flake /path/to/nix-config"
    exit 1
  fi
fi

if [ ! -f "$FLAKE_PATH/flake.nix" ]; then
  echo "ERROR: No flake.nix found at $FLAKE_PATH"
  exit 1
fi

HOST_DIR="$FLAKE_PATH/parts/hosts/$HOSTNAME"
if [ ! -d "$HOST_DIR" ]; then
  echo "ERROR: Host directory not found: $HOST_DIR"
  echo "Available hosts:"
  ls -1 "$FLAKE_PATH/parts/hosts/" 2>/dev/null || echo "  (none)"
  exit 1
fi

# ── Enable Nix experimental features (required for flakes on live USB) ──
export NIX_CONFIG="experimental-features = nix-command flakes"

# ── Gather disk info ──
DISK_BASE="$(basename "$DISK")"
DISK_MODEL="unknown"
if [ -r "/sys/block/$DISK_BASE/device/model" ]; then
  DISK_MODEL="$(cat "/sys/block/$DISK_BASE/device/model" | xargs)" || true
fi
DISK_SIZE="$(lsblk -dn -o SIZE "$DISK" 2>/dev/null || echo "unknown")"
DISK_SERIAL="$(cat "/sys/block/$DISK_BASE/device/serial" 2>/dev/null | xargs 2>/dev/null || \
               udevadm info --query=property "$DISK" 2>/dev/null | grep ID_SERIAL_SHORT | cut -d= -f2 || echo "unknown")"

IS_SSD=false
if [ "$(cat "/sys/block/$DISK_BASE/queue/rotational" 2>/dev/null)" = "0" ]; then
  IS_SSD=true
fi

# ── Minimum disk size check ──
DISK_SIZE_BYTES=$(lsblk -dn -o SIZE -b "$DISK" 2>/dev/null || echo "0")
DISK_SIZE_GB=$(( DISK_SIZE_BYTES / 1000000000 ))
if [ "$DISK_SIZE_GB" -lt 20 ]; then
  echo "WARNING: Target disk is very small (${DISK_SIZE_GB} GB)."
  echo "NixOS typically requires at least 20 GB."
  read -p "Continue anyway? (y/N): " confirm_size
  if [ "$confirm_size" != "y" ] && [ "$confirm_size" != "Y" ]; then
    echo "Aborted."
    exit 1
  fi
fi

# Determine partition naming (NVMe, eMMC, loop use 'p' separator)
if [[ "$DISK" == *nvme* ]] || [[ "$DISK" == *mmcblk* ]] || [[ "$DISK" == *loop* ]]; then
  PARTP="${DISK}p"
else
  PARTP="${DISK}"
fi

# ============================================================================
# SAFETY: Show ALL disks so user can verify they picked the right one
# ============================================================================
echo ""
echo "========== ALL DISKS ON THIS SYSTEM =========="
echo ""
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT,MODEL -e 7 2>/dev/null || \
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT -e 7
echo ""
echo "================================================"
echo ""

# Show what's currently ON the target disk
echo "========== TARGET DISK: $DISK =========="
echo ""
echo "  Model:   $DISK_MODEL"
echo "  Serial:  $DISK_SERIAL"
echo "  Size:    $DISK_SIZE"
echo "  Type:    $( $IS_SSD && echo "SSD" || echo "HDD")"
echo ""
echo "  Current contents:"
if lsblk "$DISK" -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT 2>/dev/null | tail -n +2 | grep -q .; then
  lsblk "$DISK" -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT 2>/dev/null | tail -n +2 | sed 's/^/    /'
else
  echo "    (empty / no partitions)"
fi
echo ""

# Warn if target has OS-like partitions
HAS_OS=false
if lsblk -ln -o FSTYPE "$DISK" 2>/dev/null | grep -qE 'ext4|btrfs|xfs|ntfs'; then
  HAS_OS=true
  echo "  *** WARNING: This disk contains ext4/btrfs/xfs/ntfs partitions! ***"
  echo "  *** These may contain an operating system or user data.         ***"
  echo ""
fi

# Show what the OTHER disks contain (so user can cross-check)
OTHER_DISKS=$(lsblk -dn -o NAME -e 7 | grep -v "^${DISK_BASE}$" | grep -v loop || true)
if [ -n "$OTHER_DISKS" ]; then
  echo "========== OTHER DISKS (will NOT be touched) =========="
  echo ""
  for d in $OTHER_DISKS; do
    d_model="$(cat "/sys/block/$d/device/model" 2>/dev/null | xargs || echo "?")"
    d_size="$(lsblk -dn -o SIZE "/dev/$d" 2>/dev/null || echo "?")"
    echo "  /dev/$d — $d_size — $d_model"
    lsblk "/dev/$d" -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT 2>/dev/null | tail -n +2 | sed 's/^/    /' || true
    echo ""
  done
  echo "======================================================="
  echo ""
fi

# ── Plan summary ──
# Calculate partition layout
PART_NUM=1
EFI_PART="${PARTP}${PART_NUM}"

if [ -n "$SWAP_SIZE" ]; then
  SWAP_PART="${PARTP}$((PART_NUM + 1))"
  ROOT_PART="${PARTP}$((PART_NUM + 2))"
else
  SWAP_PART=""
  ROOT_PART="${PARTP}$((PART_NUM + 1))"
fi

echo "========== INSTALLATION PLAN =========="
echo ""
echo "  Target:        $DISK ($DISK_MODEL, $DISK_SIZE)"
echo "  Hostname:      $HOSTNAME"
echo "  Encryption:    $( $ENCRYPT && echo "LUKS2" || echo "none")"
echo "  Swap:          ${SWAP_SIZE:-none}"
echo "  Filesystem:    BTRFS (compress=zstd, noatime$( $IS_SSD && echo ", ssd, discard=async"))"
echo "  Subvolumes:    @, @home, @nix, @log, @cache, @tmp, @snapshots"
echo "  Flake config:  $FLAKE_PATH#$HOSTNAME"
echo ""
echo "  Partition layout:"
echo "    ${EFI_PART}  512M   EFI System Partition (FAT32)"
if [ -n "$SWAP_SIZE" ]; then
  echo "    ${SWAP_PART}  ${SWAP_SIZE}  Swap$( $ENCRYPT && echo " (LUKS encrypted)")"
fi
echo "    ${ROOT_PART}  rest   BTRFS root$( $ENCRYPT && echo " (LUKS encrypted)")"
echo ""
echo "========================================"
echo ""

# ── First confirmation ──
echo "ALL DATA ON $DISK ($DISK_MODEL) WILL BE PERMANENTLY DESTROYED."
echo ""
read -p "Type the FULL device path to confirm (e.g. $DISK): " confirm_disk
if [ "$confirm_disk" != "$DISK" ]; then
  echo "Device path does not match. Aborted."
  exit 1
fi

# ── Second confirmation if disk has OS partitions ──
if $HAS_OS; then
  echo ""
  echo "This disk has existing OS partitions. Are you ABSOLUTELY sure?"
  read -p "Type 'ERASE' in capitals to proceed: " confirm_erase
  if [ "$confirm_erase" != "ERASE" ]; then
    echo "Aborted."
    exit 1
  fi
fi

# ============================================================================
# POINT OF NO RETURN — Everything below modifies the disk
# ============================================================================
PAST_POINT_OF_NO_RETURN=true

# ── Unmount anything on target ──
echo ""
echo ">> Cleaning up existing mounts on $DISK..."
for mp in $(findmnt -rn -o TARGET -S "$DISK" 2>/dev/null || true) \
          $(findmnt -rn -o TARGET -S "${PARTP}1" 2>/dev/null || true) \
          $(findmnt -rn -o TARGET -S "${PARTP}2" 2>/dev/null || true) \
          $(findmnt -rn -o TARGET -S "${PARTP}3" 2>/dev/null || true); do
  umount -l "$mp" 2>/dev/null || true
done
umount -R /mnt 2>/dev/null || true

# Close any LUKS devices on target partitions
for p in "${PARTP}1" "${PARTP}2" "${PARTP}3"; do
  if [ -b "$p" ]; then
    for dm in $(lsblk -ln -o NAME "$p" 2>/dev/null | tail -n +2); do
      cryptsetup close "$dm" 2>/dev/null || true
    done
  fi
done
cryptsetup close cryptroot 2>/dev/null || true
cryptsetup close cryptswap 2>/dev/null || true

# ── Partition ──
echo ">> Partitioning $DISK..."
parted "$DISK" -- mklabel gpt
parted "$DISK" -- mkpart ESP fat32 1MiB 512MiB
parted "$DISK" -- set 1 esp on

if [ -n "$SWAP_SIZE_MIB" ]; then
  SWAP_END_MIB=$(( SWAP_SIZE_MIB + 512 ))
  parted "$DISK" -- mkpart swap linux-swap 512MiB "${SWAP_END_MIB}MiB"
  parted "$DISK" -- mkpart primary "${SWAP_END_MIB}MiB" 100%
else
  parted "$DISK" -- mkpart primary 512MiB 100%
fi

# ── Wait for partition devices to appear ──
echo ">> Waiting for partition devices..."
udevadm settle 2>/dev/null || true
partprobe "$DISK" 2>/dev/null || true
udevadm settle 2>/dev/null || true

# Poll for partition device nodes (handles slow USB/network storage)
for i in $(seq 1 30); do
  if [ -b "$EFI_PART" ] && [ -b "$ROOT_PART" ]; then
    break
  fi
  sleep 0.5
done

if [ ! -b "$EFI_PART" ]; then
  echo "ERROR: Partition $EFI_PART did not appear after 15 seconds."
  echo "  Try running: partprobe $DISK"
  exit 1
fi
if [ ! -b "$ROOT_PART" ]; then
  echo "ERROR: Partition $ROOT_PART did not appear after 15 seconds."
  exit 1
fi

# ── EFI ──
echo ">> Creating EFI filesystem on $EFI_PART..."
mkfs.fat -F 32 -n BOOT "$EFI_PART"

# ── Swap (optional) ──
if [ -n "$SWAP_SIZE" ]; then
  if $ENCRYPT; then
    echo ""
    echo ">> Setting up encrypted swap on $SWAP_PART..."
    echo "   You will be prompted for a passphrase for the SWAP partition."
    echo "   TIP: Use the SAME passphrase as root — systemd unlocks both with one prompt at boot."
    echo ""
    cryptsetup luksFormat --type luks2 "$SWAP_PART"
    cryptsetup open "$SWAP_PART" cryptswap
    mkswap -L swap /dev/mapper/cryptswap
    swapon /dev/mapper/cryptswap
  else
    echo ">> Creating swap on $SWAP_PART..."
    mkswap -L swap "$SWAP_PART"
    swapon "$SWAP_PART"
  fi
fi

# ── Root partition ──
BTRFS_DEV="$ROOT_PART"
if $ENCRYPT; then
  echo ""
  echo ">> Setting up LUKS2 encryption on $ROOT_PART..."
  echo "   You will be prompted for an encryption passphrase for the ROOT partition."
  echo ""
  cryptsetup luksFormat --type luks2 "$ROOT_PART"
  echo ">> Opening LUKS device..."
  cryptsetup open "$ROOT_PART" cryptroot
  BTRFS_DEV="/dev/mapper/cryptroot"
fi

echo ">> Creating BTRFS filesystem on $BTRFS_DEV..."
mkfs.btrfs -f -L nixos "$BTRFS_DEV"

echo ">> Creating BTRFS subvolumes..."
mount "$BTRFS_DEV" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@snapshots
umount /mnt

# ── Mount subvolumes ──
echo ">> Mounting subvolumes..."
BTRFS_OPTS="compress=zstd,noatime"
if $IS_SSD; then
  BTRFS_OPTS="$BTRFS_OPTS,ssd,discard=async"
fi

mount -o "subvol=@,$BTRFS_OPTS"           "$BTRFS_DEV" /mnt
mkdir -p /mnt/{home,nix,var/log,var/cache,tmp,boot,.snapshots}
mount -o "subvol=@home,$BTRFS_OPTS"        "$BTRFS_DEV" /mnt/home
mount -o "subvol=@nix,$BTRFS_OPTS"         "$BTRFS_DEV" /mnt/nix
mount -o "subvol=@log,$BTRFS_OPTS"         "$BTRFS_DEV" /mnt/var/log
mount -o "subvol=@cache,$BTRFS_OPTS"       "$BTRFS_DEV" /mnt/var/cache
mount -o "subvol=@tmp,$BTRFS_OPTS"         "$BTRFS_DEV" /mnt/tmp
mount -o "subvol=@snapshots,$BTRFS_OPTS"   "$BTRFS_DEV" /mnt/.snapshots
mount "$EFI_PART" /mnt/boot

echo ">> Generating hardware-configuration.nix..."
nixos-generate-config --root /mnt

# ── Copy hardware config into flake ──
if [ ! -f /mnt/etc/nixos/hardware-configuration.nix ]; then
  echo "ERROR: nixos-generate-config did not produce hardware-configuration.nix"
  echo "  This may indicate a hardware detection issue."
  echo "  You can create this file manually and re-run with --no-install."
  exit 1
fi

echo ">> Copying hardware-configuration.nix into flake..."
cp /mnt/etc/nixos/hardware-configuration.nix "$HOST_DIR/hardware-configuration.nix"
echo "   Saved: $HOST_DIR/hardware-configuration.nix"

echo ""
echo "============================================"
echo " Disk Setup Complete!"
echo "============================================"
echo ""
echo " Result:"
lsblk "$DISK" -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT
echo ""

if $DO_INSTALL; then
  echo ">> Installing NixOS from $FLAKE_PATH#$HOSTNAME ..."
  echo ""
  nixos-install --flake "$FLAKE_PATH#$HOSTNAME" --no-root-passwd
  echo ""
  echo "============================================"
  echo " Installation Complete!"
  echo "============================================"
  echo ""
  echo " Post-install steps:"
  echo "  1. Set user password:"
  echo "     nixos-enter --root /mnt -c 'passwd <username>'"
  echo ""
  echo "  2. Reboot:"
  echo "     reboot"
  echo ""
  echo " sops-nix secrets — after first boot, EITHER:"
  echo ""
  echo "  Generate a new age key:"
  echo "    sudo mkdir -p /var/lib/sops-nix"
  echo "    sudo age-keygen -o /var/lib/sops-nix/key.txt"
  echo ""
  echo "  OR copy from a backup:"
  echo "    sudo mkdir -p /var/lib/sops-nix"
  echo "    sudo cp /path/to/backup/key.txt /var/lib/sops-nix/key.txt"
  echo ""
  echo "  Then update secrets/secrets.yaml with the public key and rebuild."
else
  echo " Next steps:"
  echo "  1. Review hardware config: $HOST_DIR/hardware-configuration.nix"
  echo "  2. Install: nixos-install --flake $FLAKE_PATH#$HOSTNAME --no-root-passwd"
  echo "  3. Set password: nixos-enter --root /mnt -c 'passwd <username>'"
  echo "  4. Reboot: reboot"
fi

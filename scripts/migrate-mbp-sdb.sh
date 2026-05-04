#!/usr/bin/env bash
# migrate-mbp-sdb.sh — online 1:1 migration of MacBook Pro 9,2 root from
# Kingston A400 (/dev/sda, ata2 optical-bay caddy) to Samsung PM841
# (/dev/sdb, ata1 main bay).
#
# Runs entirely from the currently booted system on sda. No live USB.
# sda is NEVER touched — it stays bootable as a rollback until you
# explicitly wipe it (outside this script).
#
# 1:1 scope: clones @, @home, @nix, @log, @cache via btrfs send/receive.
# Creates empty @snapshots (nested snaps have parent-chain refs) and @tmp.
# Preserves nix generation rollback history, journalctl logs, caches.
#
# Usage:
#   ./scripts/migrate-mbp-sdb.sh           interactive (default)
#   ./scripts/migrate-mbp-sdb.sh --yes     skip confirms (LUKS passphrase still prompts)
#   ./scripts/migrate-mbp-sdb.sh --clean   abort + cleanup any partial prior run
#   ./scripts/migrate-mbp-sdb.sh --help    this message
#
# Failure recovery:
#   • Any failure before reboot → sda unchanged, just reboot normally.
#   • Mid-send failure → re-run with --clean, then re-run normally.
#   • nixos-install failure → sdb has data but no bootloader. Script
#     prints the exact retry command. sda still bootable.
#
# After successful reboot from sdb, merge to main:
#   cd ~/Documents/nix && git checkout main && git merge migrate-to-sdb-YYYYMMDD && git push

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────
# SRC/DST discovered at runtime — sd* letters are NOT stable across boots.
# SRC = drive holding /dev/mapper/cryptroot (running root).
# DST = the other internal SATA disk (Samsung; rejects anything else).
detect_disks() {
  local root_src root_part root_disk other
  root_src=$(findmnt -n -o SOURCE / | cut -d'[' -f1)
  # -snl = reverse-tree + list format (no └─ chars). First partition ancestor.
  root_part=$(lsblk -snlo NAME,TYPE "$root_src" 2>/dev/null |
    awk '$2=="part" {print $1; exit}')
  [ -z "$root_part" ] && die "Could not resolve root partition from $root_src"
  root_disk=$(lsblk -nslo PKNAME "/dev/$root_part" 2>/dev/null | head -1)
  [ -z "$root_disk" ] && die "Could not resolve parent disk of /dev/$root_part"
  SRC_DISK="/dev/$root_disk"
  # DST = first non-SRC internal SATA disk
  other=$(lsblk -ndo NAME,TYPE,TRAN |
    awk -v src="$(basename "$SRC_DISK")" '$2=="disk" && $3=="sata" && $1!=src {print "/dev/"$1; exit}')
  [ -z "$other" ] && die "No second internal SATA disk found"
  DST_DISK="$other"
}
detect_disks
DST_EFI="${DST_DISK}1"
DST_LUKS="${DST_DISK}2"
DST_MAPPER_NAME="cryptroot-new"
DST_MAPPER="/dev/mapper/${DST_MAPPER_NAME}"
TARGET_MOUNT="/mnt/sdb-new"
STAGE_MOUNT="/mnt/sdb-stage"
SNAPSHOT_PREFIX="/.snapshots/migrate-$(date +%Y%m%d-%H%M)"
BRANCH="migrate-to-sdb-$(date +%Y%m%d)"
LOG="$HOME/migrate-to-sdb-$(date +%Y%m%d-%H%M%S).log"
GIT_AUTHOR_NAME="Daaboulex"
GIT_AUTHOR_EMAIL="39669593+Daaboulex@users.noreply.github.com"
FLAKE_DIR="$HOME/Documents/nix"

# Subvol list — order matters (parents mount before children)
# Format: "subvol_name:source_mount:mode"  mode = clone|empty
SUBVOLS=(
  "@:/:clone"
  "@home:/home:clone"
  "@nix:/nix:clone"
  "@log:/var/log:clone"
  "@cache:/var/cache:clone"
  "@snapshots:/.snapshots:empty"
  "@tmp:/tmp:empty"
)

# Global state — updated as script progresses; error trap consults it
# CURRENT_PHASE + AUTO_YES cross into sourced lib/disk-ops.sh
export CURRENT_PHASE="init"
export AUTO_YES=0
MODE="run"

# ── Arg parsing ─────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
  --yes) AUTO_YES=1 ;;
  --clean) MODE="clean" ;;
  --help | -h)
    sed -n '2,28p' "$0"
    exit 0
    ;;
  *) echo "Unknown arg: $arg (see --help)" && exit 2 ;;
  esac
done

# ── Helpers (shared with repurpose-kingston.sh) ─────────────────────────
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib/disk-ops.sh"

# Unmount all our mount points (idempotent)
unmount_all() {
  for mp in "$TARGET_MOUNT/boot" "$TARGET_MOUNT/tmp" "$TARGET_MOUNT/.snapshots" \
    "$TARGET_MOUNT/var/cache" "$TARGET_MOUNT/var/log" "$TARGET_MOUNT/nix" \
    "$TARGET_MOUNT/home" "$TARGET_MOUNT" \
    "$STAGE_MOUNT"; do
    if mountpoint -q "$mp" 2>/dev/null; then
      sudo umount -l "$mp" 2>/dev/null || true
    fi
  done
}

# Close our LUKS if open
close_luks() {
  if sudo cryptsetup status "$DST_MAPPER_NAME" &>/dev/null; then
    sudo cryptsetup close "$DST_MAPPER_NAME" 2>/dev/null || true
  fi
}

# Delete source-side migration snapshots (match SNAPSHOT_PREFIX pattern)
delete_src_snapshots() {
  # Remove snapshots created by THIS run only
  for suffix in "" "-home" "-nix" "-log" "-cache"; do
    local snap="${SNAPSHOT_PREFIX}${suffix}"
    [ -d "$snap" ] && sudo btrfs subvolume delete "$snap" &>/dev/null || true
  done
}

# Delete all migrate-* snapshots (for --clean mode)
delete_all_migrate_snapshots() {
  for snap in /.snapshots/migrate-*; do
    [ -d "$snap" ] || continue
    sudo btrfs subvolume delete "$snap" &>/dev/null || true
    log "  removed $snap"
  done
}

# Error trap: best-effort cleanup
cleanup_on_error() {
  local exit_code=$?
  log ""
  log "╔══════════════════════════════════════════════════════════════════"
  log "║ ERROR at phase: $CURRENT_PHASE (exit $exit_code)"
  log "╚══════════════════════════════════════════════════════════════════"
  unmount_all
  close_luks
  delete_src_snapshots

  # Phase-specific recovery guidance
  case "$CURRENT_PHASE" in
  "7 — nixos-install")
    cat <<EOF | tee -a "$LOG"

nixos-install failed. DST ($DST_DISK) has subvolume data but no bootloader yet.
SRC ($SRC_DISK) is UNTOUCHED — reboot normally if needed.

To retry just the install step (without re-cloning data):
  sudo cryptsetup open $DST_LUKS $DST_MAPPER_NAME
  sudo mount -o subvol=@,compress=zstd:1,noatime,ssd,discard=async,commit=30 $DST_MAPPER $TARGET_MOUNT
  sudo mkdir -p $TARGET_MOUNT/{home,nix,var/log,var/cache,.snapshots,tmp,boot}
  for sv in home:@home nix:@nix var/log:@log var/cache:@cache .snapshots:@snapshots tmp:@tmp; do
    sudo mount -o subvol=\${sv##*:},compress=zstd:1,noatime,ssd,discard=async,commit=30 $DST_MAPPER $TARGET_MOUNT/\${sv%%:*}
  done
  sudo mount $DST_EFI $TARGET_MOUNT/boot
  cd $FLAKE_DIR && git checkout $BRANCH
  sudo nixos-install --root $TARGET_MOUNT --flake .#macbook-pro-9-2 --no-root-passwd --no-channel-copy

EOF
    ;;
  "4 — send/receive" | "3 — empty subvols" | "2 — partition + LUKS")
    cat <<EOF | tee -a "$LOG"

Partial state on DST ($DST_DISK). To retry from scratch:
  ./scripts/migrate-mbp-sdb.sh --clean    # wipes intermediate state
  ./scripts/migrate-mbp-sdb.sh            # start fresh

EOF
    ;;
  esac

  log "SRC ($SRC_DISK) is UNTOUCHED. Current system boots normally from SRC."
  log "Log: $LOG"
}

# ── --clean mode ────────────────────────────────────────────────────────
if [ "$MODE" = "clean" ]; then
  log "=== migrate-mbp-sdb.sh --clean ==="
  log "Removes: mounted sdb (if any), open LUKS, migration snapshots on sda."
  log "Does NOT touch: sdb partition table / data, main branch, any committed work."
  confirm "Proceed with cleanup?"
  unmount_all
  close_luks
  log "Unmounted + closed LUKS."
  delete_all_migrate_snapshots
  log "Removed /.snapshots/migrate-* snapshots."
  # Remove migration branch if it exists AND we're not on it
  cd "$FLAKE_DIR"
  CUR=$(git symbolic-ref --short HEAD 2>/dev/null || echo DETACHED)
  for br in $(git for-each-ref --format='%(refname:short)' refs/heads/migrate-to-sdb-*); do
    [ "$CUR" = "$br" ] && continue
    git branch -D "$br" 2>/dev/null && log "  removed branch $br" || true
  done
  log "Clean complete."
  exit 0
fi

# ── Trap + preamble ─────────────────────────────────────────────────────
trap cleanup_on_error ERR

log "=== migrate-mbp-sdb.sh starting ==="
log "Log: $LOG"
log "Mode: run  (auto-yes=$AUTO_YES)"

[ "$(id -u)" = "0" ] && die "Do NOT run as root. Script uses sudo internally."
[ -d "$FLAKE_DIR/.git" ] || die "Flake dir not found: $FLAKE_DIR"

# Refresh sudo cache so big sections don't re-prompt
sudo -v || die "sudo failed"

# ── Phase 1: Pre-flight checks ──────────────────────────────────────────
phase "1 — pre-flight"

# Running root (strip btrfs [/subvol] suffix)
ROOT_SRC=$(findmnt -n -o SOURCE / | cut -d'[' -f1)
[ "$ROOT_SRC" = "/dev/mapper/cryptroot" ] ||
  die "Root is $ROOT_SRC, expected /dev/mapper/cryptroot"
log "✓ Running root: $ROOT_SRC on SRC_DISK=$SRC_DISK ($(lsblk -nd -o MODEL "$SRC_DISK"))"
log "✓ Migration target: DST_DISK=$DST_DISK ($(lsblk -nd -o MODEL "$DST_DISK"))"

# sda subvols present (warn if any missing)
for entry in "${SUBVOLS[@]}"; do
  IFS=':' read -r name path mode <<<"$entry"
  [ "$mode" = "clone" ] || continue
  sudo btrfs subvolume show "$path" &>/dev/null ||
    die "Expected subvol $name at $path — not found. Aborting to avoid incomplete clone."
done
log "✓ All expected source subvolumes present"

# DST must be Samsung (sanity — prevents wiping wrong drive if detection misfires)
DST_MODEL=$(lsblk -n -d -o MODEL "$DST_DISK" 2>/dev/null | head -1)
[ -z "$DST_MODEL" ] && die "$DST_DISK not found"
echo "$DST_MODEL" | grep -qi "SAMSUNG" ||
  die "$DST_DISK is '$DST_MODEL' — refusing (expected Samsung). Verify detect_disks() output."
log "✓ Destination model: $DST_MODEL"

# sdb unmounted
mount | grep -q "^$DST_DISK" &&
  die "$DST_DISK or its partitions are mounted. Unmount or run with --clean first."
log "✓ $DST_DISK unmounted"

# sdb size
SDB_SIZE=$(lsblk -bn -d -o SIZE "$DST_DISK")
SDB_SIZE_GB=$((SDB_SIZE / 1024 / 1024 / 1024))
[ "$SDB_SIZE_GB" -lt 200 ] && die "$DST_DISK too small: ${SDB_SIZE_GB}G, need >= 200G"
log "✓ $DST_DISK size: ${SDB_SIZE_GB}G"

# sda btrfs used
ROOT_USED_GB=$(sudo btrfs filesystem usage -g / 2>/dev/null |
  awk '/Used:/ {gsub(/GiB/,""); print int($2); exit}')
[ -z "$ROOT_USED_GB" ] && ROOT_USED_GB=$(df -BG --output=used / | tail -1 | tr -dc '0-9')
log "  sda btrfs used: ${ROOT_USED_GB}G"
[ "$ROOT_USED_GB" -ge "$SDB_SIZE_GB" ] &&
  die "sda data (${ROOT_USED_GB}G) won't fit on sdb (${SDB_SIZE_GB}G)"

# Flake git state
cd "$FLAKE_DIR"
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo DETACHED)
[ "$CURRENT_BRANCH" = "main" ] ||
  die "Flake not on 'main' branch (on '$CURRENT_BRANCH'). Checkout main first."
DIRTY=$(git status --porcelain | head -1)
if [ -n "$DIRTY" ]; then
  log "⚠  Flake has uncommitted changes:"
  git status --short | tee -a "$LOG"
  confirm "Include uncommitted changes in migration branch?"
fi

# Current UUIDs
# Source UUIDs — detect partitions rather than hardcoded -2/-1 suffix
SRC_LUKS_PART=$(lsblk -nlo NAME,FSTYPE "$SRC_DISK" | awk '$2=="crypto_LUKS" {print "/dev/"$1; exit}')
SRC_EFI_PART=$(lsblk -nlo NAME,FSTYPE "$SRC_DISK" | awk '$2=="vfat" {print "/dev/"$1; exit}')
[ -z "$SRC_LUKS_PART" ] && die "No LUKS partition on $SRC_DISK"
[ -z "$SRC_EFI_PART" ] && die "No EFI/vfat partition on $SRC_DISK"
SRC_LUKS_UUID=$(sudo cryptsetup luksUUID "$SRC_LUKS_PART")
SRC_EFI_UUID=$(sudo blkid -s UUID -o value "$SRC_EFI_PART")
log "  SRC LUKS UUID ($SRC_LUKS_PART): $SRC_LUKS_UUID"
log "  SRC /boot UUID ($SRC_EFI_PART): $SRC_EFI_UUID"

# Final confirm — single gate before ANY destructive work
log ""
cat <<EOF
────────────────────────────────────────────────────────────────────
  Ready to migrate: $SRC_DISK (Kingston A400) → $DST_DISK ($DST_MODEL)

  WILL WIPE $DST_DISK ENTIRELY (these partitions will be destroyed):
$(lsblk "$DST_DISK" | sed 's/^/    /')

  WILL clone (preserves history): @, @home, @nix, @log, @cache
  WILL create empty: @snapshots, @tmp
  $SRC_DISK will NOT be touched and stays bootable.

  Total time estimate: 60-120 min (depends on data volume + SSD speed).
  You may keep using the system during clone — I/O-heavy tasks will be
  slow though.

────────────────────────────────────────────────────────────────────
EOF
confirm "Start migration?"

# ── Phase 2: Partition + LUKS + btrfs on sdb ────────────────────────────
phase "2 — partition + LUKS"

sudo wipefs -a "$DST_DISK"
sudo parted "$DST_DISK" -- mklabel gpt
sudo parted "$DST_DISK" -- mkpart ESP fat32 1MiB 513MiB
sudo parted "$DST_DISK" -- set 1 esp on
sudo parted "$DST_DISK" -- mkpart primary 513MiB 100%
sudo partprobe "$DST_DISK"
sleep 2
# Verify partitions appeared in /dev
[ -b "$DST_EFI" ] || die "$DST_EFI did not appear after partprobe"
[ -b "$DST_LUKS" ] || die "$DST_LUKS did not appear after partprobe"
sudo mkfs.vfat -F 32 -n boot "$DST_EFI"
log "✓ Partitioned $DST_DISK"

echo
echo "  Enter LUKS passphrase for $DST_LUKS:"
echo "  (Recommend same as sda for convenience — cryptsetup will ask twice.)"
echo
sudo cryptsetup luksFormat --type luks2 --batch-mode --verify-passphrase "$DST_LUKS"
echo
echo "  Unlock $DST_LUKS:"
sudo cryptsetup open "$DST_LUKS" "$DST_MAPPER_NAME"
sudo mkfs.btrfs -f -L nixos "$DST_MAPPER"
log "✓ LUKS + btrfs created"

# ── Phase 3: Empty subvols + staging mount ──────────────────────────────
phase "3 — empty subvols"

sudo mkdir -p "$STAGE_MOUNT"
sudo mount "$DST_MAPPER" "$STAGE_MOUNT"
for entry in "${SUBVOLS[@]}"; do
  IFS=':' read -r name path mode <<<"$entry"
  [ "$mode" = "empty" ] || continue
  sudo btrfs subvolume create "$STAGE_MOUNT/$name"
  log "  created empty $name"
done

# ── Phase 4: Clone all data subvols (send/receive) ──────────────────────
phase "4 — send/receive"

sudo mkdir -p "/.snapshots"

clone_subvol() {
  local src_mount="$1" target_name="$2"
  local snap="${SNAPSHOT_PREFIX}-${target_name//@/}"
  local recvd
  recvd="$(basename "$snap")"
  local start end
  start=$(date +%s)

  log "  [$target_name] snapshotting $src_mount"
  sudo btrfs subvolume snapshot -r "$src_mount" "$snap"

  log "  [$target_name] sending → $STAGE_MOUNT (progress in bytes)"
  # Use pv if available for progress; fall back to plain pipe
  if command -v pv &>/dev/null; then
    sudo sh -c "btrfs send '$snap' | pv -prb | btrfs receive '$STAGE_MOUNT/'"
  else
    sudo sh -c "btrfs send '$snap' | btrfs receive '$STAGE_MOUNT/'"
  fi

  sudo mv "$STAGE_MOUNT/$recvd" "$STAGE_MOUNT/$target_name"
  # -f required: received subvols carry received_uuid; btrfs refuses
  # ro→rw flip without -f to protect incremental-send parent lookup.
  # We don't need incremental send on these — first install, not a btrbk chain.
  sudo btrfs property set -f -ts "$STAGE_MOUNT/$target_name" ro false
  end=$(date +%s)
  log "  ✓ $target_name ready (took $((end - start))s)"
}

for entry in "${SUBVOLS[@]}"; do
  IFS=':' read -r name path mode <<<"$entry"
  [ "$mode" = "clone" ] || continue
  clone_subvol "$path" "$name"
done

sudo umount "$STAGE_MOUNT"
sudo rmdir "$STAGE_MOUNT" 2>/dev/null || true
log "✓ All subvolumes cloned"

# ── Phase 5: Mount sdb layout for install ───────────────────────────────
phase "5 — mount for install"

BTRFS_OPTS="compress=zstd:1,noatime,ssd,discard=async,commit=30"
sudo mkdir -p "$TARGET_MOUNT"
sudo mount -o "subvol=@,$BTRFS_OPTS" "$DST_MAPPER" "$TARGET_MOUNT"
sudo mkdir -p "$TARGET_MOUNT"/{home,nix,var/log,var/cache,.snapshots,tmp,boot}
for pair in "home:@home" "nix:@nix" "var/log:@log" "var/cache:@cache" \
  ".snapshots:@snapshots" "tmp:@tmp"; do
  dir="${pair%%:*}"
  sv="${pair##*:}"
  sudo mount -o "subvol=$sv,$BTRFS_OPTS" "$DST_MAPPER" "$TARGET_MOUNT/$dir"
done
sudo mount "$DST_EFI" "$TARGET_MOUNT/boot"
log "✓ Mounted sdb at $TARGET_MOUNT"

# ── Phase 6: Flake UUID update on migration branch ──────────────────────
phase "6 — flake UUID update"

DST_LUKS_UUID=$(sudo cryptsetup luksUUID "$DST_LUKS")
DST_EFI_UUID=$(sudo blkid -s UUID -o value "$DST_EFI")
log "  sdb LUKS UUID: $DST_LUKS_UUID"
log "  sdb /boot UUID: $DST_EFI_UUID"

cd "$FLAKE_DIR"
# Re-run safety: recreate branch if exists
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  log "  branch $BRANCH already exists — deleting + recreating"
  git checkout main
  git branch -D "$BRANCH"
fi
git checkout -b "$BRANCH"

HC_FILE="parts/hosts/macbook-pro-9-2/hardware-configuration.nix"
DK_FILE="parts/hosts/macbook-pro-9-2/disko.nix"

sed -i "s|by-uuid/${SRC_LUKS_UUID}|by-uuid/${DST_LUKS_UUID}|g" "$HC_FILE"
sed -i "s|by-uuid/${SRC_EFI_UUID}|by-uuid/${DST_EFI_UUID}|g" "$HC_FILE"
sed -i "s|by-uuid/${SRC_LUKS_UUID}|by-uuid/${DST_LUKS_UUID}|g" "$DK_FILE"

# Sanity: the replacements must have happened
grep -q "$DST_LUKS_UUID" "$HC_FILE" ||
  die "sed did not update LUKS UUID in $HC_FILE"
grep -q "$DST_EFI_UUID" "$HC_FILE" ||
  die "sed did not update /boot UUID in $HC_FILE"

log "  diff:"
git diff --stat "$HC_FILE" "$DK_FILE" | tee -a "$LOG"

log "  direct config eval (skip flake check — known-stale store refs)..."
# `nix flake check` fails on stale checkInputs derivation refs unrelated to
# our edits. Direct eval of the target config is what matters for install.
nix eval --json ".#nixosConfigurations.macbook-pro-9-2.config.system.build.toplevel.drvPath" 2>&1 |
  tail -1 | tee -a "$LOG" | grep -q '^"/nix/store' ||
  die "Config eval failed after UUID edit — inspect $HC_FILE + $DK_FILE"
log "✓ Config evaluates to a valid toplevel derivation"

git -c user.email="$GIT_AUTHOR_EMAIL" -c user.name="$GIT_AUTHOR_NAME" \
  add "$HC_FILE" "$DK_FILE"
git -c user.email="$GIT_AUTHOR_EMAIL" -c user.name="$GIT_AUTHOR_NAME" \
  commit -m "migrate: sda → sdb UUIDs (Samsung PM841, main SATA bay)

LUKS = $DST_LUKS_UUID
/boot = $DST_EFI_UUID

Migration branch — do NOT merge until reboot from sdb verified."
log "✓ Committed to branch $BRANCH"

# ── Phase 7: nixos-install ──────────────────────────────────────────────
phase "7 — nixos-install"

log "Installing NixOS onto $TARGET_MOUNT (15-30 min; pulls from /nix/store)"
sudo nixos-install --root "$TARGET_MOUNT" \
  --flake "$FLAKE_DIR#macbook-pro-9-2" \
  --no-root-passwd --no-channel-copy 2>&1 | tee -a "$LOG"

# Post-install verification
[ -f "$TARGET_MOUNT/boot/loader/loader.conf" ] ||
  die "systemd-boot not installed at $TARGET_MOUNT/boot/loader/loader.conf"
[ -L "$TARGET_MOUNT/run/current-system" ] || [ -d "$TARGET_MOUNT/nix/var/nix/profiles" ] ||
  die "No current-system on sdb — nixos-install incomplete"
log "✓ systemd-boot + current-system verified on sdb"

# ── Phase 8: Cleanup + instructions ─────────────────────────────────────
phase "8 — cleanup"

delete_src_snapshots
log "✓ Removed migration snapshots from sda"

unmount_all
close_luks
log "✓ Unmounted sdb + closed LUKS"

trap - ERR
CURRENT_PHASE="done"

log ""
cat <<EOF | tee -a "$LOG"
═══════════════════════════════════════════════════════════════════
  MIGRATION COMPLETE
═══════════════════════════════════════════════════════════════════

Next steps:
  1. sudo reboot
  2. At chime: hold Option (⌥) — Mac EFI boot picker appears.
  3. Pick the NEW Samsung (sdb) entry.
  4. After login, verify from sdb:
       lsblk                         # root on sdb
       iodiag                        # new I/O baseline
       lsmod | grep b43              # WiFi loaded
       efibootmgr -v                 # see all boot entries
  5. If everything works, merge to main:
       cd ~/Documents/nix
       git checkout main
       git merge $BRANCH
       git push origin main

Rollback (if sdb won't boot or misbehaves):
  • Reboot, hold Option, pick OLD sda entry. sda is 100% intact.
  • On sda: git checkout main (UUID change is on branch only)

Log: $LOG
EOF

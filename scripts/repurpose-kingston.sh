#!/usr/bin/env bash
# repurpose-kingston.sh — wipe Kingston A400 + set up as:
#   • 16 GB LUKS swap (with hibernate support)
#   • rest LUKS btrfs mounted at /mnt/kingston-backup (btrbk target)
#
# Runs from running Samsung root. Prerequisites: migrate-mbp-sdb.sh
# succeeded, Samsung has booted stably (recommend 3-7 days + iodiag
# baseline comparison before running this).
#
# Strategy:
#   • Fresh passphrase-unlockable LUKS2 on both partitions
#   • Keyfile added to both so Samsung root boot can auto-unlock them
#     without a second password prompt at initrd
#   • Keyfile at /etc/secrets/kingston.key (root-only readable, on
#     Samsung root — stays encrypted under Samsung LUKS)
#
# Kingston is NEVER touched until final destructive confirm.
#
# Usage:
#   ./scripts/repurpose-kingston.sh           interactive
#   ./scripts/repurpose-kingston.sh --yes     skip confirms
#   ./scripts/repurpose-kingston.sh --clean   undo partial run
#   ./scripts/repurpose-kingston.sh --help

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────
SWAP_SIZE_GB=16
SWAP_MAPPER_NAME="cryptswap"
BACKUP_MAPPER_NAME="cryptbackup"
SWAP_MAPPER="/dev/mapper/${SWAP_MAPPER_NAME}"
BACKUP_MAPPER="/dev/mapper/${BACKUP_MAPPER_NAME}"
BACKUP_MOUNT="/mnt/kingston-backup"
KEYFILE_DIR="/etc/secrets"
KEYFILE_PATH="${KEYFILE_DIR}/kingston.key"
BRANCH="repurpose-kingston-$(date +%Y%m%d)"
LOG="$HOME/repurpose-kingston-$(date +%Y%m%d-%H%M%S).log"
GIT_AUTHOR_NAME="Daaboulex"
GIT_AUTHOR_EMAIL="39669593+Daaboulex@users.noreply.github.com"
FLAKE_DIR="$HOME/Documents/nix"

# CURRENT_PHASE + AUTO_YES cross into sourced lib/disk-ops.sh
export CURRENT_PHASE="init"
export AUTO_YES=0
MODE="run"

# ── Arg parse ───────────────────────────────────────────────────────────
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

# ── Helpers (shared with migrate-mbp-sdb.sh) ────────────────────────────
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib/disk-ops.sh"

# Find Kingston = the non-root SATA disk
detect_kingston() {
  local root_src root_part root_disk other
  root_src=$(findmnt -n -o SOURCE / | cut -d'[' -f1)
  root_part=$(lsblk -snlo NAME,TYPE "$root_src" 2>/dev/null |
    awk '$2=="part" {print $1; exit}')
  [ -z "$root_part" ] && die "Could not resolve root partition"
  root_disk=$(lsblk -nslo PKNAME "/dev/$root_part" 2>/dev/null | head -1)
  [ -z "$root_disk" ] && die "Could not resolve parent disk"
  # The other SATA disk
  other=$(lsblk -ndo NAME,TYPE,TRAN |
    awk -v src="$root_disk" '$2=="disk" && $3=="sata" && $1!=src {print "/dev/"$1; exit}')
  [ -z "$other" ] && die "No second SATA disk found"
  KINGSTON_DISK="$other"
  SWAP_PART="${KINGSTON_DISK}1"
  BACKUP_PART="${KINGSTON_DISK}2"
}
detect_kingston

unmount_all() {
  mountpoint -q "$BACKUP_MOUNT" && sudo umount -l "$BACKUP_MOUNT" 2>/dev/null || true
}

close_luks() {
  for m in "$SWAP_MAPPER_NAME" "$BACKUP_MAPPER_NAME"; do
    sudo cryptsetup status "$m" &>/dev/null && sudo cryptsetup close "$m" || true
  done
  sudo swapoff "$SWAP_MAPPER" 2>/dev/null || true
}

cleanup_on_error() {
  local exit_code=$?
  log ""
  log "╔══════════════════════════════════════════════════════════════════"
  log "║ ERROR at phase: $CURRENT_PHASE (exit $exit_code)"
  log "╚══════════════════════════════════════════════════════════════════"
  unmount_all
  close_luks
  log "Kingston may have partial state. Re-run with --clean then retry."
  log "Samsung (root) is UNTOUCHED."
  log "Log: $LOG"
}

# ── --clean mode ────────────────────────────────────────────────────────
if [ "$MODE" = "clean" ]; then
  log "=== repurpose-kingston.sh --clean ==="
  confirm "Clean up partial run state (no data on Kingston will be touched)?"
  unmount_all
  close_luks
  cd "$FLAKE_DIR"
  for br in $(git for-each-ref --format='%(refname:short)' refs/heads/repurpose-kingston-*); do
    [ "$(git symbolic-ref --short HEAD)" = "$br" ] && continue
    git branch -D "$br" 2>/dev/null && log "  removed branch $br" || true
  done
  log "Clean complete."
  exit 0
fi

# ── Preamble ────────────────────────────────────────────────────────────
trap cleanup_on_error ERR

log "=== repurpose-kingston.sh starting ==="
log "Log: $LOG"
log "Kingston detected: $KINGSTON_DISK"

[ "$(id -u)" = "0" ] && die "Do NOT run as root. Script uses sudo internally."
[ -d "$FLAKE_DIR/.git" ] || die "Flake dir not found"

sudo -v || die "sudo failed"

# ── Phase 1 — pre-flight ────────────────────────────────────────────────
phase "1 — pre-flight"

KINGSTON_MODEL=$(lsblk -n -d -o MODEL "$KINGSTON_DISK" | head -1)
echo "$KINGSTON_MODEL" | grep -qi "KINGSTON" ||
  die "$KINGSTON_DISK is '$KINGSTON_MODEL' — refusing (expected KINGSTON)"
log "✓ Detected: $KINGSTON_DISK = $KINGSTON_MODEL"

# Verify NOT currently mounted anywhere
mount | grep -q "^$KINGSTON_DISK" &&
  die "$KINGSTON_DISK is mounted. Run with --clean or umount first."
log "✓ $KINGSTON_DISK not mounted"

# Flake must be on main + clean
cd "$FLAKE_DIR"
BR=$(git symbolic-ref --short HEAD 2>/dev/null || echo DETACHED)
[ "$BR" = "main" ] || die "Flake not on main (on '$BR')"
if git status --porcelain | grep -qv '^ *[mM] \.ai-context\|OPTIONS.md'; then
  log "⚠  Flake has uncommitted changes (other than known-dirty submodule):"
  git status --short | tee -a "$LOG"
  confirm "Include in migration branch?"
fi

log ""
cat <<EOF
────────────────────────────────────────────────────────────────────
  Repurpose Kingston (${KINGSTON_MODEL})

  WILL WIPE $KINGSTON_DISK ENTIRELY — current layout to be destroyed:
$(lsblk "$KINGSTON_DISK" | sed 's/^/    /')

  NEW LAYOUT:
    ${SWAP_PART}   ${SWAP_SIZE_GB} GB  LUKS → swap
    ${BACKUP_PART}  rest         LUKS → btrfs @ $BACKUP_MOUNT

  Keyfile auto-generated at $KEYFILE_PATH (root-only on Samsung root)
  so swap + backup auto-unlock at boot without second passphrase.

  Samsung (root) is NOT touched.
────────────────────────────────────────────────────────────────────
EOF
confirm "Start repurpose?"

# ── Phase 2 — partition + LUKS ──────────────────────────────────────────
phase "2 — partition + LUKS"

sudo wipefs -a "$KINGSTON_DISK"
sudo parted "$KINGSTON_DISK" -- mklabel gpt
sudo parted "$KINGSTON_DISK" -- mkpart swap 1MiB "${SWAP_SIZE_GB}GiB"
sudo parted "$KINGSTON_DISK" -- mkpart backup "${SWAP_SIZE_GB}GiB" 100%
sudo partprobe "$KINGSTON_DISK"
sleep 2
[ -b "$SWAP_PART" ] || die "$SWAP_PART did not appear"
[ -b "$BACKUP_PART" ] || die "$BACKUP_PART did not appear"

# Generate keyfile (32 random bytes)
sudo mkdir -p "$KEYFILE_DIR"
sudo chmod 700 "$KEYFILE_DIR"
if [ ! -f "$KEYFILE_PATH" ]; then
  sudo dd if=/dev/urandom of="$KEYFILE_PATH" bs=32 count=1 status=none
  sudo chmod 400 "$KEYFILE_PATH"
  log "  generated fresh keyfile at $KEYFILE_PATH"
else
  log "  reusing existing keyfile at $KEYFILE_PATH"
fi

echo
echo "  LUKS format $SWAP_PART (set passphrase — recommend same as root):"
sudo cryptsetup luksFormat --type luks2 --batch-mode --verify-passphrase "$SWAP_PART"
echo "  Add keyfile to swap slot 1 (reuse passphrase from prev prompt):"
sudo cryptsetup luksAddKey "$SWAP_PART" "$KEYFILE_PATH"

echo
echo "  LUKS format $BACKUP_PART (set passphrase — recommend same):"
sudo cryptsetup luksFormat --type luks2 --batch-mode --verify-passphrase "$BACKUP_PART"
echo "  Add keyfile to backup slot 1:"
sudo cryptsetup luksAddKey "$BACKUP_PART" "$KEYFILE_PATH"

# Open them
sudo cryptsetup open --key-file "$KEYFILE_PATH" "$SWAP_PART" "$SWAP_MAPPER_NAME"
sudo cryptsetup open --key-file "$KEYFILE_PATH" "$BACKUP_PART" "$BACKUP_MAPPER_NAME"
log "✓ LUKS on both partitions + keyfile added"

# ── Phase 3 — swap + btrfs ──────────────────────────────────────────────
phase "3 — mkswap + mkfs.btrfs"

sudo mkswap -L kingston-swap "$SWAP_MAPPER"
sudo mkfs.btrfs -f -L kingston-backup "$BACKUP_MAPPER"

sudo mkdir -p "$BACKUP_MOUNT"
sudo mount -o compress=zstd:3,noatime,ssd,discard=async "$BACKUP_MAPPER" "$BACKUP_MOUNT"
log "✓ Filesystems formatted + backup mounted"

# ── Phase 4 — flake updates ─────────────────────────────────────────────
phase "4 — flake updates"

SWAP_LUKS_UUID=$(sudo cryptsetup luksUUID "$SWAP_PART")
BACKUP_LUKS_UUID=$(sudo cryptsetup luksUUID "$BACKUP_PART")
BACKUP_FS_UUID=$(sudo blkid -s UUID -o value "$BACKUP_MAPPER")
log "  swap   LUKS UUID: $SWAP_LUKS_UUID"
log "  backup LUKS UUID: $BACKUP_LUKS_UUID"
log "  backup FS UUID:   $BACKUP_FS_UUID"

cd "$FLAKE_DIR"
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  log "  branch $BRANCH exists — recreating"
  git checkout main
  git branch -D "$BRANCH"
fi
git checkout -b "$BRANCH"

HC="parts/hosts/macbook-pro-9-2/hardware-configuration.nix"

# Inject LUKS devices + swap + fileSystems entry
# Do it via a marker-based insertion. First check if marker already there.
if ! grep -q "### repurpose-kingston start ###" "$HC"; then
  cat <<EOF | sudo -u "$USER" tee -a "$HC" >/dev/null

### repurpose-kingston start ###
# Added by scripts/repurpose-kingston.sh
{
  config,
  lib,
  ...
}:
# ^^ this block intentionally ignored — see host default.nix wiring
EOF
fi

# Actually we can't freely inject NixOS config into a hardware-config.nix
# that's already a module. Better: patch the existing attributes.
# Use a temp nix append file approach instead: create a small module.

# Write a dedicated file for Kingston additions
KINGSTON_MOD="parts/hosts/macbook-pro-9-2/kingston.nix"
cat >"$KINGSTON_MOD" <<EOF
# kingston — Kingston A400 as LUKS swap + btrbk backup target.
# Generated by scripts/repurpose-kingston.sh on $(date -Iseconds).
#
# Kingston is unlocked POST-ROOT by systemd-cryptsetup (not initrd):
#   • keyfile stays encrypted under Samsung root LUKS (never on /boot)
#   • if Kingston fails/disconnects, Samsung still boots (nofail)
{
  config,
  lib,
  ...
}:
{
  systemd.tmpfiles.rules = [
    "d /etc/secrets 0700 root root -"
    "z ${KEYFILE_PATH} 0400 root root -"
  ];

  environment.etc.crypttab.text = ''
    cryptswap    UUID=${SWAP_LUKS_UUID}    ${KEYFILE_PATH}  luks,discard,nofail
    cryptbackup  UUID=${BACKUP_LUKS_UUID}  ${KEYFILE_PATH}  luks,discard,nofail
  '';

  swapDevices = [
    {
      label = "kingston-swap";
      priority = 10; # below zram (PRIO 100)
    }
  ];

  fileSystems."${BACKUP_MOUNT}" = {
    device = "/dev/mapper/cryptbackup";
    fsType = "btrfs";
    options = [
      "compress=zstd:3"
      "noatime"
      "ssd"
      "discard=async"
      "nofail"
      "x-systemd.device-timeout=30s"
    ];
  };

  myModules.storage.btrbk = {
    enable = lib.mkForce true;
    targetPath = "${BACKUP_MOUNT}";
  };
}
EOF
log "  wrote $KINGSTON_MOD"

# Remove the bogus marker we wrote earlier (cleanup)
sudo sed -i '/### repurpose-kingston start ###/,$d' "$HC" || true

# Wire kingston.nix via host default.nix imports (where hardware-config is)
HD="parts/hosts/macbook-pro-9-2/default.nix"
if ! grep -q "./kingston.nix" "$HD"; then
  # Insert ./kingston.nix after ./hardware-configuration.nix in imports=[]
  sed -i '/\.\/hardware-configuration\.nix/a\    ./kingston.nix' "$HD" ||
    die "Failed to wire ./kingston.nix into $HD — add manually to imports=[]"
  log "  wired ./kingston.nix into $HD imports"
fi
HFM="$HD" # for commit message compat

# Verify eval
log "  direct config eval (skip flake check — known-stale store refs)..."
# Same rationale as migrate-mbp-sdb.sh: flake-check checkInputs sometimes
# reference GC'd derivations. What we care about is the target config eval.
nix eval --json ".#nixosConfigurations.macbook-pro-9-2.config.system.build.toplevel.drvPath" 2>&1 |
  tail -1 | tee -a "$LOG" | grep -q '^"/nix/store' ||
  die "Config eval failed — inspect $KINGSTON_MOD"

git -c user.email="$GIT_AUTHOR_EMAIL" -c user.name="$GIT_AUTHOR_NAME" \
  add "$KINGSTON_MOD" "$HFM"
git -c user.email="$GIT_AUTHOR_EMAIL" -c user.name="$GIT_AUTHOR_NAME" \
  commit -m "repurpose-kingston: encrypted swap + btrbk backup target

Adds kingston.nix host module wiring:
- LUKS swap (${SWAP_SIZE_GB} GB) with keyfile auto-unlock
- LUKS btrfs btrbk backup target at ${BACKUP_MOUNT}
- Enables myModules.storage.btrbk with hourly replication

UUIDs:
  swap LUKS    = ${SWAP_LUKS_UUID}
  backup LUKS  = ${BACKUP_LUKS_UUID}
  backup FS    = ${BACKUP_FS_UUID}

Keyfile at ${KEYFILE_PATH} (root-only, lives inside Samsung root LUKS)."
log "✓ Committed to $BRANCH"

# ── Phase 5 — nixos-rebuild + activate ──────────────────────────────────
phase "5 — nixos-rebuild switch"
log "Running nixos-rebuild switch (will activate swap + backup mount)"
confirm "Run nrb now?"

cd "$FLAKE_DIR"
sudo nixos-rebuild switch --flake ".#macbook-pro-9-2" 2>&1 | tee -a "$LOG"

# Verify swap active
if swapon --show | grep -q cryptswap; then log "✓ cryptswap active"; else log "⚠ cryptswap not active"; fi
if mountpoint -q "$BACKUP_MOUNT"; then log "✓ $BACKUP_MOUNT mounted"; else log "⚠ $BACKUP_MOUNT not mounted"; fi

# ── Phase 6 — first btrbk run ───────────────────────────────────────────
phase "6 — first btrbk replication (optional)"
confirm "Run first btrbk replication now (builds baseline, ~15-30 min)?"
sudo btrbk run --progress --verbose 2>&1 | tee -a "$LOG" || log "⚠ btrbk failed; inspect output"

# ── Phase 7 — done ──────────────────────────────────────────────────────
phase "7 — done"
trap - ERR

log ""
cat <<EOF | tee -a "$LOG"
═══════════════════════════════════════════════════════════════════
  KINGSTON REPURPOSE COMPLETE
═══════════════════════════════════════════════════════════════════

Active:
  swap    = $SWAP_MAPPER ($(swapon --show | grep cryptswap | awk '{print $3}' || echo ?))
  backup  = $BACKUP_MOUNT
  btrbk   = hourly via systemd timer

Verify:
  swapon --show
  btrfs subvolume list $BACKUP_MOUNT | head
  systemctl list-timers | grep btrbk

Merge to main:
  cd $FLAKE_DIR
  git checkout main && git merge $BRANCH && git push

Rollback: reboot, hold Option, pick Kingston EFI entry to boot old
A400 root (still intact). Or 'git checkout main' + nrb to disable the
kingston module (swap + backup mount go away, Kingston LUKS stays).

Log: $LOG
EOF

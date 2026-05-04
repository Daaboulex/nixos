# MacBook Pro 9,2 Storage Strategy

Context: two internal drives; one is root, the other has leftover OS
partitions. Goal: live redundancy + testable migration away from a
failing/slow primary, without reinstalling.

## Current State (as of 2026-04-18)

```
/dev/sda  KINGSTON SA400S37240G  223.6 GB  Primary (LUKS + btrfs, root)
  ├─ sda1 511 MB    vfat    /boot
  └─ sda2 223.1 GB  LUKS
     └─ cryptroot   btrfs   /  /home  /nix  /var/log  /var/cache  /.snapshots  /tmp

/dev/sdb  SAMSUNG MZMTE256HMHP   238.5 GB  Secondary (legacy OS partitions)
  ├─ sdb1 200 MB    vfat   (old EFI)
  ├─ sdb2 116.4 GB  apfs   (old macOS)
  └─ sdb3 121.9 GB  ntfs   (old Windows)
```

SMART: sda shows moderate wear. Run `sudo smartctl -a /dev/sda` for current
values. DRAM-less controller + btrfs CoW = elevated write amplification.

Samsung PM841 (sdb) has DRAM cache — expected to be materially better for
btrfs workloads.

## Options (ranked by reversibility + effort)

### Option A — Migration test: clone btrfs to sdb, boot from it

Non-destructive to sda. Tests whether the A400 is the hang cause.

1. Back up sdb's APFS + NTFS first (or accept wiping them).
2. Wipe sdb, create matching LUKS + btrfs layout.
3. Live-clone with `btrfs replace` (online) or offline with `btrfs send | btrfs receive` from a live USB.
4. Install bootloader on sdb, add boot menu entry.
5. Reboot, select sdb — same system, different drive.
6. Run the same workload for a week. Measure `/proc/pressure/io` with `iodiag`.
7. If pressure drops significantly → A400 confirmed as cause. Keep sdb as root.
8. If pressure is similar → A400 is NOT the sole cause. Look elsewhere (btrfs tuning, I/O-heavy processes).

**Pros:** Definitive test. Reversible (sda is untouched).
**Cons:** One-week commitment to gather evidence. Requires offline boot from
live USB for the initial send/receive (or `btrfs replace` can do it online).

### Option B — Live snapshot replication with `btrbk` (the user's "two clones" ask)

Not RAID. Separate failure domains. Hourly btrfs snapshots on sda,
replicated to sdb via `btrfs send | btrfs receive`. If sda dies, sdb has
the last hourly snapshot — boot into a recovery environment and restore.

Structure:

```
sda (primary, active root) ──[btrfs-send]──► sdb (snapshot archive)
  cryptroot:                                   cryptroot:
    @  (live)                                    snapshots/<date>/@
    @home                                        snapshots/<date>/@home
    @nix                                         snapshots/<date>/@nix
    @snapshots                                   (rotating retention)
```

Retention policy example (configurable in `btrbk.conf`):

- Hourly: keep 24
- Daily: keep 14
- Weekly: keep 8
- Monthly: keep 6

NixOS module path: `myModules.storage.btrbk` wraps upstream `services.btrbk`
(see `parts/storage/btrbk.nix`). Wired on both hosts — only macbook has a
second drive, so ryzen keeps `enable = false`.

**Pros:** Live backup, separate drive, RAID avoided. Failure of sda → sdb
has last-hour snapshot. Failure of sdb → sda keeps running.
**Cons:** sdb is NOT directly bootable without a restore step. Maintenance:
snapshot tree grows, needs retention tuning.

### Option C — Full bootable mirror (Option A + B combined)

sdb is both a snapshot archive AND a bootable clone. Periodic task:
receive latest snapshot, promote to `@` on sdb, rewrite sdb's bootloader.

**Pros:** Failure of sda → reboot into sdb with no restore.
**Cons:** Most complex. Boot entries to maintain. Bootloader rewrites
on every promote.

### Option D — RAID1 (user explicitly rejected)

Disk mirroring at the block layer. Correlated failure (bad sector on one
→ silent corruption propagates). Write corruption from a bad controller
duplicates onto the "good" drive. Rejected.

## Recommendation

Two-step:

**Step 1 — Option A (migration test)** to find out if the A400 is actually the bottleneck.

- If yes: make sdb the primary, demote sda to snapshot target via Option B.
- If no: keep sda as primary, add Option B for live backup, investigate other causes.

This avoids committing to Option C's complexity until we know the
underlying problem.

## Preconditions Before Touching sdb

1. **Decide fate of sdb2 (APFS macOS) and sdb3 (NTFS Windows).** Options:
   - Archive to external drive, then wipe
   - Shrink both, carve 80-120 GB for the clone
   - Full wipe
2. **Full backup of critical paths on sda** (especially `~/Documents/nix/` already pushed to origin; personal docs maybe not).
3. **Create a live NixOS USB** for recovery + initial clone.

## Questions for the User

1. sdb2 (macOS 116 GB) + sdb3 (Windows 122 GB): **wipe, shrink, or archive first?**
2. Target size on sdb for the clone: **full 223 GB mirror (wipe sdb) or minimal boot+root ~80 GB (shrink existing)?**
3. When ready to proceed: **weekend offline window or incremental steps during the week?**

## Automated migration script

For the most common path — full migration from sda to sdb, online, no live
USB — use **`scripts/migrate-mbp-sdb.sh`** from the flake root.

It does everything listed below automatically: pre-flight checks, partition,
LUKS format, btrfs subvolumes, atomic snapshot + send/receive of `@` and
`@home`, UUID edits to `hardware-configuration.nix` + `disko.nix` committed
on a `migrate-to-sdb-YYYYMMDD` branch, then `nixos-install` onto sdb.

```sh
cd ~/Documents/nix
./scripts/migrate-mbp-sdb.sh          # interactive, confirmation at each destructive step
./scripts/migrate-mbp-sdb.sh --yes    # skip prompts (LUKS passphrase still prompts)
```

sda is **never touched**. Rollback after reboot: hold Option (⌥) at the
Mac chime, pick the old sda entry. The migration branch stays separate
from `main` until you verify and merge.

## Commands (for reference — not to run yet)

```sh
# Inspect current sdb partition content
sudo mount -o ro /dev/sdb2 /mnt
ls /mnt  # see what's on macOS partition

# Wipe + new GPT
sudo wipefs -a /dev/sdb
sudo parted /dev/sdb mklabel gpt

# Partition (example: 512 MB EFI, rest LUKS)
sudo parted /dev/sdb mkpart ESP fat32 1MiB 513MiB
sudo parted /dev/sdb set 1 esp on
sudo parted /dev/sdb mkpart primary 513MiB 100%
sudo mkfs.vfat -F 32 /dev/sdb1

# LUKS + btrfs
sudo cryptsetup luksFormat /dev/sdb2
sudo cryptsetup open /dev/sdb2 cryptroot2
sudo mkfs.btrfs /dev/mapper/cryptroot2

# Subvolume layout matching current sda
sudo mount /dev/mapper/cryptroot2 /mnt
for sv in @ @home @nix @log @cache @snapshots @tmp; do
  sudo btrfs subvolume create /mnt/$sv
done

# Live clone (online, btrfs native): send each subvolume
# Requires read-only snapshot of source first.
sudo btrfs subvolume snapshot -r / /.snapshots/migrate-@
sudo btrfs send /.snapshots/migrate-@ | sudo btrfs receive /mnt/
# ... repeat for @home, @nix, etc.
```

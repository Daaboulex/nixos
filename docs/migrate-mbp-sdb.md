# migrate-mbp-sdb.sh — quick reference

Online 1:1 migration of NixOS root from Kingston A400 (`sda`) to Samsung PM841 (`sdb`). No live USB.

## TL;DR

```sh
cd ~/Documents/nix
./scripts/migrate-mbp-sdb.sh
# → answer prompts, enter LUKS passphrase, wait ~60-120 min
sudo reboot
# → hold Option (⌥) at chime, pick new Samsung entry
git checkout main && git merge migrate-to-sdb-$(date +%Y%m%d) && git push
```

## What it does

1. **Pre-flight** — verifies drives, sizes, git on `main`, sda subvols present
2. **Partition sdb** — 512 MB ESP + rest LUKS2
3. **LUKS + btrfs** — prompts you for a passphrase (same as sda = easiest)
4. **Clone subvols** via `btrfs send/receive` (1:1 — preserves history):
   - `@`, `@home`, `@nix`, `@log`, `@cache`
   - Empty created: `@snapshots`, `@tmp`
5. **Update flake UUIDs** in `hardware-configuration.nix` + `disko.nix`
6. **Commit to migration branch** `migrate-to-sdb-YYYYMMDD` (never touches `main`)
7. **`nixos-install`** onto sdb — writes bootloader, registers EFI entry
8. **Cleanup** — unmounts, closes LUKS, removes temp snapshots

## Flags

| Flag        | Purpose                                                                                                   |
| ----------- | --------------------------------------------------------------------------------------------------------- |
| _(no flag)_ | Interactive: one upfront confirm + LUKS passphrase                                                        |
| `--yes`     | Skip confirms (LUKS still prompts — cryptsetup requirement)                                               |
| `--clean`   | Undo a partial failed run: unmount, close LUKS, delete migration snapshots + branches. Does NOT wipe sdb. |
| `--help`    | Show header docs                                                                                          |

## Time

~60-120 min total. Breakdown (SATA-3, 120 GB data):

- Phase 1-2 (checks + format): ~2 min
- Phase 3-4 (clone): 40-80 min ← the long one
- Phase 5-6 (UUID edits + commit + flake check): ~2 min
- Phase 7 (nixos-install): 10-30 min
- Phase 8 (cleanup): ~1 min

Install `pv` for live progress bars during Phase 4 (optional; script auto-detects).

## If it fails

| Fails at                             | What's on disk                  | What to do                                       |
| ------------------------------------ | ------------------------------- | ------------------------------------------------ |
| Phase 1 (checks)                     | nothing                         | fix the reported issue, re-run                   |
| Phase 2-4 (sdb partition/LUKS/clone) | sdb partially written           | `--clean` + re-run                               |
| Phase 5-6 (mount/UUID/commit)        | sdb populated, no bootloader    | `--clean` + re-run                               |
| Phase 7 (nixos-install)              | sdb populated, no bootloader    | script prints exact retry command; sda untouched |
| Phase 8 (cleanup)                    | all good but temp state lingers | run `--clean`                                    |

**sda is never touched in any phase** — reboot normally if needed.

## After reboot from sdb

Verify:

```sh
lsblk                    # root should be /dev/sdb2[/@]
iodiag                   # new I/O pressure baseline vs A400 baseline
lsmod | grep b43         # WiFi still loads
efibootmgr -v            # both sda + sdb in boot list
```

Merge migration branch:

```sh
cd ~/Documents/nix
git checkout main && git merge migrate-to-sdb-YYYYMMDD && git push
```

## Rollback

At any point before reboot: just reboot. sda is unchanged.

After reboot, if sdb misbehaves:

1. Reboot, hold Option (⌥), pick **old sda entry**
2. sda boots exactly as before
3. On sda: `git checkout main` (UUID change lives on branch only)

## Decommission sda later (optional)

After 1-2 weeks of stable sdb operation:

```sh
# Option A: keep sda as live backup target (separate failure domain)
#   → I'll add a myModules.storage.btrbk module

# Option B: wipe + use sda as scratch
sudo wipefs -a /dev/sda

# Option C: wipe only sda's EFI so it stops appearing in Mac boot picker
sudo dd if=/dev/zero of=/dev/sda1 bs=1M count=512
```

## Files touched by the script

| File                                                     | Change                                  |
| -------------------------------------------------------- | --------------------------------------- |
| `/dev/sdb`                                               | wiped + partitioned + LUKS + btrfs      |
| `parts/hosts/macbook-pro-9-2/hardware-configuration.nix` | UUIDs on migration branch               |
| `parts/hosts/macbook-pro-9-2/disko.nix`                  | UUIDs on migration branch               |
| `~/migrate-to-sdb-*.log`                                 | full run log                            |
| `/.snapshots/migrate-*`                                  | temp read-only snapshots (auto-cleaned) |

Nothing else is touched. No system services restarted. No config outside the flake edited.

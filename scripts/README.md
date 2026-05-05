# Scripts

Operational scripts for this NixOS configuration. Not imported by the flake
— these are invoked directly by humans or by pre-commit hooks.

## Inventory

| Script | Purpose |
|--------|---------|
| `audit-probes.sh` | Mechanical-axiom probes for full-audit meta-spec |
| `b43-resume-verify.sh` | Verify b43 WiFi reload hook works after suspend on MBP 9,2 |
| `deploy.sh` | Deploy NixOS config to a remote host via SSH |
| `generate-docs.nix` | Produce `docs/OPTIONS.md` + `docs/options.json` from live option tree |
| `generate-hm-template.nix` | Produce `docs/hm-host-template.nix.example` from HM options |
| `generate-host-template.nix` | Produce `docs/host-template.nix.example` from NixOS options |
| `generate-readme-sections.nix` | Produce auto-generated README sections (modules, layout, inputs) |
| `install-btrfs.sh` | Full NixOS install: LUKS + BTRFS + disko from live USB |
| `migrate-mbp-sdb.sh` | Online 1:1 migration of MBP root between SSDs |
| `repurpose-kingston.sh` | Wipe Kingston A400 + set up as LUKS swap + btrbk backup target |
| `sync-repos.sh` | Pull all `repos/` subdirectories from their GitHub remotes |
| `test-shell-functions.sh` | Integration tests for nrb, nrb-check, nrb-info |
| `update-docs.sh` | Manually regenerate everything the `update-docs` hook produces |
| `vfio-phase1-probe.sh` | Gather VFIO data (BAR2, IOMMU groups, PCI topology) |
| `warm-macbook-cache.sh` | Pre-build macbook config on ryzen for faster remote switch |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `git-hooks/` | Hook scripts referenced by `parts/_build/git-hooks.nix` |
| `lib/` | Shared shell library (`disk-ops.sh` — disk detection, LUKS helpers) |

## Usage

All shell scripts support `--help` or have usage comments at the top.
Scripts that perform destructive operations prompt for confirmation
(pass `--yes` to skip for automation).

The Nix scripts (`generate-*.nix`) are pure expressions evaluated via
`nix eval --raw --impure --file <script> <attr>` — no derivation build
required.

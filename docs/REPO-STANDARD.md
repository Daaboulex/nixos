# Daaboulex Nix Packaging Standard — v1.3

Canonical reference for all `repos/` satellite flakes under `Daaboulex/`.
Version 1.3 (2026-05-05) — adds documentation standardization with splice
markers, pre-commit doc hooks, README auto-sync via `sync.sh`.

## What changed from v1.2 → v1.3

- **README splice markers**: all READMEs use `<!-- BEGIN/END generated:X -->`
  markers for badges, upstream, installation, options, footer sections.
  Managed by `sync.sh` + `readme-sync.py`.
- **3-badge standard**: CI + NixOS-unstable + License (was 6 in v1.2, then
  2 in initial v1.3, restored CI badge in v1.3.1 — CI is the only dynamic
  badge that shows live build health).
- **Upstream table**: standardized 3-row table (Project, License, Tracked)
  replacing the old bullet-list format.
- **Pre-commit doc hooks**: `typos`, `rumdl`, `check-readme-sections` added
  to all 22 repos. Module repos also get `update-readme-options.sh`.
- **Repo count**: 22 repos in `repos.json` (was 20 at v1.1, unchanged in v1.2).
- **Folder naming**: local folder names match GitHub repo names exactly.

## What changed from v1.1 → v1.2

- **Editor / agent scaffold lockdown**: no repo may track ephemeral
  per-user or per-host editor / coding-agent scaffold files. The
  enumerated pattern set is listed below under "Forbidden paths";
  enforcement is via `templates/gitignore`, idempotent un-track on sync,
  and a `scaffold-lockdown` CI job that fails the build if any forbidden
  pattern appears in `git ls-files`.
- **Dependabot**: weekly GitHub Actions SHA updates, registered via
  `.github/dependabot.yml`.
- **SECURITY.md**: private vulnerability reporting policy (GHSA).
- **Branch protection**: ruleset on default branch — deletion +
  force-push blocked (owner bypass allowed).
- **Default branch naming**: `main` for all non-fork repos
  (upstream-tracking forks may keep `master`).

## Required files (satellite packaging repo)

```text
.github/
├── dependabot.yml          # weekly Actions updates
├── update.json             # update contract (verify block + upstream spec)
└── workflows/
    ├── ci.yml              # scaffold-lockdown + eval + fmt + build + verify
    ├── maintenance.yml     # weekly flake.lock + stale branch cleanup
    └── update.yml          # scheduled upstream polling
scripts/
├── update.sh               # update contract implementation
├── check-readme-sections.sh          # pre-commit: validates splice markers
└── update-readme-options.sh          # (module repos) splices options into README
.editorconfig
.gitignore                  # scaffold patterns (see templates/gitignore)
flake.nix                   # formatter + checks (pre-commit) + devShells + package
LICENSE
README.md
SECURITY.md
```

## Pre-commit hooks (required in flake.nix)

All repos must declare these hooks in the `git-hooks.lib.${system}.run` block:

| Hook                    | Source   | Purpose                               |
| ----------------------- | -------- | ------------------------------------- |
| `nixfmt-rfc-style`      | built-in | Nix code formatting                   |
| `typos`                 | built-in | Catches common typos across all files |
| `rumdl`                 | built-in | Markdown lint for README and docs     |
| `check-readme-sections` | custom   | Validates README splice markers exist |

Module repos (`nixosModules` or `homeManagerModules` output) additionally ship
`scripts/update-readme-options.sh` for future options-table auto-generation.

Local scaffold files (coding-agent config, session notes, ephemeral state)
stay outside the tracked tree via the gitignore pattern set.

## Forbidden paths (never tracked)

Pattern used by `scaffold-lockdown` CI job and `templates/gitignore`:

```text
CLAUDE.md
GEMINI.md
AGENTS.md
AI-progress.json
AI-tasks.json
.session-handoff.md
.pre-commit-config.yaml
.claude/
.gemini/
.ai-context/
.cursor/
.superpowers/
memory/
self-improvements-pending-*.jsonl
```

## CI contract (`ci.yml`)

Three jobs, in dependency order:

1. **`scaffold-lockdown`** — fails if `git ls-files` matches any
   forbidden path.
2. **`check`** (depends on `scaffold-lockdown`) — runs `nix flake check
--no-build`, `nix fmt -- --check .`, `nix build`, then post-build
   verification per `.github/update.json`.
3. Actions pinned to full commit SHAs (never `@v4` or floating tags).

## Update contract (`scripts/update.sh`)

- Exit 0: no update, or update succeeded
- Exit 1: update found but build/verification failed → `maintenance.yml`
  opens GitHub Issue with log
- Exit 2: network/API error → retry next run
- Outputs: `updated`, `new_version`, `old_version`, `package_name`,
  `error_type`, `upstream_url`
- Verification chain: eval → clean build → binary verify → ldd check
- **Never false-positive**: every check must pass before push to `main`

## Flake shape

- Inputs: `nixpkgs/nixos-unstable` + `git-hooks.nix`
  (with `nixpkgs.follows`)
- No `flake-utils` — use `nixpkgs.lib.genAttrs`
- Pattern: `localSystem.system = system`
- Outputs: `formatter`, `checks` (pre-commit integration), `devShells`
  (shellHook + nil), `packages`, `overlays.default`
- Module-only repos: `nixosModules.default` + `homeManagerModules.default`

## Branch protection

- Default branch: protected via ruleset
  - Deletion: blocked
  - Non-fast-forward (force-push): blocked (owner bypass allowed for
    exceptional cases — history rewrite, secret purge)
- Solo-dev workflow: direct push to default branch allowed; CI runs on
  every push for visibility but is not a merge gate

## Dependabot

- `.github/dependabot.yml` registers GitHub Actions ecosystem
- Weekly schedule, Monday 06:00 UTC
- Auto-opens PRs bumping pinned Action SHAs — review + merge to keep
  supply chain fresh

## Onboarding / sync

Operator tooling (templates, `sync.sh`, repo registry) is tracked
privately. The public-facing contract is the structure above: any repo
that satisfies the required files, forbidden paths, CI contract, flake
shape, and branch protection rules is standard-conformant.

## Why these rules exist

- **Scaffold lockdown**: prior leaks of per-user / per-host editor
  scaffold files into public repos. Fixed by (a) strong gitignore,
  (b) idempotent un-track on sync, (c) CI job catching any relapse,
  (d) one-time history filter-repo scrub across all non-fork repos
  (2026-04-22).

  Main config repo (`Daaboulex/nixos`) uses the complementary content
  gate documented in STYLE.md §8.5 (`check-scrub-tokens` hook reading
  `~/.ai-context/scripts/scrub-config.json`). Both gates source the
  same canonical catalog.

- **Branch protection**: prior absence meant accidental force-push
  could silently overwrite remote. Owner bypass kept for intentional
  history rewrites.
- **Dependabot**: pinned SHAs age quickly. Without automated bumps, CI
  silently runs on stale Actions that may deprecate. Weekly PRs
  trickle-in updates with review.
- **Default branch `main`**: consistency across non-forks. Forks stay
  on `master` to simplify upstream tracking.

## Upstream breakage resilience

Packages that patch upstream sources (kernel modules, QEMU stealth,
mesa-git) are vulnerable to upstream reorganization. Defend with:

1. **Version assertion** — `assert lib.assertMsg (lib.hasPrefix expected
version)` at the top of the package. Eval fails loudly when upstream
   bumps past the pinned version instead of silently applying wrong
   patches.

2. **Path-pinned patches** — reference patches by full path from the
   flake input (`"${input}/patches/Foo/Bar.patch"`). When upstream moves
   or renames the file, the build fails with `No such file or directory`
   — immediately actionable.

3. **Fix = update path, not fork** — when upstream reorganizes (e.g.
   moves patches to `Archive/`), update the path reference. Never fork
   the upstream input just to preserve old paths.

4. **update.sh awareness** — if the repo's `update.sh` bumps the
   upstream input automatically, it must also verify the patch paths
   still exist post-bump. If not, it should exit 1 (build failure →
   GitHub Issue) rather than silently pushing a broken main.

5. **Transitional comments** — when a patch targets a specific upstream
   version range, comment the expected transition:
   ```nix
   # When nixpkgs bumps QEMU to 11.x:
   #   1. Change expectedVersionPrefix to "11."
   #   2. Switch patch from Archive/AMD-v10.2.0.patch to AMD-v11.0.0.patch
   ```

## Related

- `docs/STYLE.md` — Nix coding standards (shared across main config + repos).
- `docs/REPO-DOC-TEMPLATE.md` — README + `docs/` shape contract (v2.1).
  REPO-STANDARD covers files/CI/flake; REPO-DOC-TEMPLATE covers the
  prose layout inside README.md and the optional `docs/` folder for
  Tier 3 repos.

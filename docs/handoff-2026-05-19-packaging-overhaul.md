---
title: "Session handoff — packaging-updater overhaul (continuation)"
type: handoff
created: 2026-05-19
---

# Session handoff — 2026-05-19 packaging overhaul

Continuation of the `2026-05-19-001-nix-packaging-updater-overhaul` spec.
The spec (`docs/specs/2026-05-19-001-nix-packaging-updater-overhaul.md`) has
the full design + execution log; this handoff is the session-level summary
plus everything that lives outside the spec.

## Done — committed & pushed

All commits below are pushed. The main `nix` repo working tree is clean.

### main `nix` repo (`Daaboulex/nixos@main`)

| Commit    | What                                                                                                                                                                                                                          |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ceebed8` | `refactor(home)`: SSH `programs.ssh.matchBlocks` → `programs.ssh.settings` on both hosts (HM deprecated `matchBlocks`). Verified per-host via narrow `programs.ssh.settings` eval.                                            |
| `ec289b5` | `feat(repo-standard)`: Phase A hardening — `update.sh` hash-extraction oscillation guard + `re_esc` regex escaping + `versionScheme`; `update.yml` github-script injection hardening; new `drift-check.yml`; schema + README. |
| `2082549` | `fix(repo-standard)`: spell out `BRE`/`fre` for the `typos` hook.                                                                                                                                                             |
| `cd3732e` | `docs(spec)`: log Phase A/B + openviking plan.                                                                                                                                                                                |
| `550eed5` | `docs(spec)`: openviking progress + eden split-manifest finding.                                                                                                                                                              |
| `fcf1959` | `feat(repo-standard)`: opt-in **Cachix** workflow (`cachix.yml`) + `sync.sh` + README.                                                                                                                                        |

### packaging repos

- **Phase B fleet re-sync** — all 21 `repos/*-nix` re-synced from the
  canonical (`update.sh` + `update.yml` + new `drift-check.yml`). All 21
  **drift-check green** (note: drift-check verifies only
  `scripts/update.sh` byte-for-byte — not the synced workflow files) and
  all 21 **CI green** (full package build). Method: fresh shallow clones
  into `/tmp/fleet/` (never the stale local `repos/*`), commit + push.
- **lsfg-vk-nix** — opted into `versionScheme: "unstable-date"`;
  `package.nix` version is `1.0.0-unstable-2026-04-25` (base = the latest
  _stable_ release `v1.0.0`; `compareVersions`-safe).
- **openviking-nix** (`@e80ca155`) — full **0.3.17 port**: deleted
  `agfs.nix` (Go AGFS gone), added `ragfs-python.nix` (PyO3/maturin),
  rewrote `flake.nix`/`ov-cli.nix`/`package.nix` (shared cargo vendor,
  refreshed Python closure incl. 4 new wheels). **CI green.**
  Update-failed issue #4 closed.
- **eden-nix** — bespoke `type: custom` updater:
  - `@3a4af39` — bespoke `scripts/update.sh` (Gitea-aware, date-stamped
    version, orchestrates `sync-deps.py`); `update.json` → `type: custom`.
  - `@269e325` — the real fix: point the updater at
    `externals/cpmfile.json` (the bundled-dep manifest) not the root
    `cpmfile.json` (system libs); reverted the `SKIP_KEYS` band-aid.
  - The updater is verified working end-to-end (a dispatched Update run
    bumped + re-derived deps + recomputed the hash).

### `.ai-context` (auto-synced submodule)

- `scripts/scrub-config.json` — `Daaboulex` allowlisted for `repo-standard/**`.
- `projects/nix/memory/` — new `feedback_lmstudio_ifd_eval_downloads.md`;
  `MEMORY.md` + `macbook-deploy-workflow` updated.
- The harness memory symlink (under `~/.claude/projects/…/memory`) was
  repointed from a broken `…/project-state/nix/memory` target to the live
  `~/.ai-context/projects/nix/memory`.

## Open — needs follow-up

1. **eden-nix PR #10 (`sdl3-migration`)** — eden `2026-05-18` migrated
   SDL2 → SDL3 (SDL3 has no system path; always CPM-bundled). The PR adds
   `sdl3` to `deps/default.nix` (`libsdl-org/SDL` `release-3.4.8`, the
   `git_version` tag — self-maintained by `sync-deps.py`), bundles it into
   the CPM cache, adds SDL3's X11/Wayland/audio build deps, drops system
   SDL2, bumps eden to `2026-05-18`. **`nix build --dry-run` instantiated
   clean; the full compile is on CI.** → When CI is green, merge to `main`.
   If CI fails it is almost certainly a missing SDL3 build-dep — add it to
   `package.nix` `buildInputs` on the branch and re-push.
2. **Cachix fleet re-sync** — `cachix.yml` is in `repo-standard/` and
   `sync.sh`, but not yet synced to the 21 repos. Run
   `repo-standard/sync.sh` (fresh clones, per the Phase B method), commit +
   push each. The workflow is inert until a repo/org sets the
   `CACHIX_CACHE` variable + `CACHIX_AUTH_TOKEN` secret — see
   `repo-standard/README.md`. User action: create the Cachix cache + add
   the secret/variable.
3. **Task 5 — promote `repo-standard/` to its own repo**
   (`Daaboulex/nix-packaging-standard`). Deferred deliberately: doing it
   re-points `drift-check.yml`'s canonical URL and forces another 21-repo
   re-sync. Do it once `repo-standard/` has stabilised.
4. **`sync-deps.py` warnings** (eden-nix) — `spirv-tools` and `mcl` are in
   `deps/default.nix` but not `cpmfile.json` (they are `CPMAddPackage`
   deps in eden's CMake, not the JSON manifest). Pre-existing; cosmetic.
5. **`nrb` intermittent no-text-output bug** — still needs a reproduction.
6. **`vkBasalt_overlay_wayland`** — local dir is not a git clone (Wave 5).
7. **`gemini-cli-nix`** — orphan, not wired as a flake input (spec open
   decision).

## Verification done this session

- Phase A: `bash -n`, `shellcheck`, `actionlint`, `typos` on all canonical
  files; `cachix.yml` `actionlint`-clean.
- Phase B: all 21 repos — drift-check ✅ + CI ✅.
- openviking: CI ✅ (full package build on the runner).
- eden updater: exercised end-to-end via a dispatched Update run.
- eden SDL3: `nix build --dry-run` instantiates clean; CI compile pending.
- SSH migration: `programs.ssh.settings` evaluates + type-checks on both
  hosts.

## Post-review audit (2026-05-19)

Two independent reviewers (a Codex agent and a Claude agent) audited this
session. The Claude audit confirmed every "done" claim is genuinely done
and the `repo-standard/` files are internally consistent. Findings, with
disposition:

**Fixed this session**

- `update.yml` shell injection — the `Push update` `run:` block
  interpolated `${{ }}` outputs directly; the failure step's `execSync`
  built shell strings from `pkg`/`newV`. Both fixed: outputs now pass via
  `env:`, and the failure step uses `execFileSync('git', [...])` (no
  shell). Canonical change — distributes with the pending fleet re-sync.

**Open follow-ups (real, not yet fixed)**

- _HIGH_ — `update.sh` `unstable-date`: rev detection greps the first
  `rev = "` in any `*.nix` file. A multi-source package could match a
  dependency's rev. (Today's only `unstable-date` repo, lsfg-vk, has one
  `rev` — latent, not active.)
- _HIGH_ — `openviking-nix/package.nix` `postInstall` only `echo`es a
  warning when `ov` / `ragfs_python*.so` are missing; it should `exit 1`
  so CI fails loudly. (Carried over from the 0.2.10 packaging.)
- _MEDIUM_ — `drift-check.yml` verifies only `scripts/update.sh`, not the
  other synced workflow files. Extending it to all canonical files would
  make "drift-check green" mean what it sounds like.
- _MEDIUM_ — `update.schema.json` does not model per-`type` required
  `upstream` fields and lacks `additionalProperties: false` on `upstream`;
  bad config fails in shell, not at validation.
- _MEDIUM_ — `cachix.yml` checks `CACHIX_CACHE` but not
  `CACHIX_AUTH_TOKEN`; if the variable is set without the secret, the job
  runs and fails at push instead of skipping.
- _MEDIUM_ — `update.sh` version-write: the success check greps the new
  version anywhere in the file (not the target attr); the write regex
  lacks the read-side identifier boundary; `verify.args` is passed as a
  single argument.
- _LOW_ — `sync-deps.py` (eden) treats removed deps / fetch failures as
  warnings with exit 0; `git_host` is ignored for tag/sha URLs (eden's
  deps are all GitHub today).
- _cosmetic_ — the spec has a duplicated "flake input owner casing"
  paragraph and a stale `openviking-nix#3` pointer (issue is closed).

The HIGH/MEDIUM items are genuine hardening follow-ups for a focused
pass; none breaks current behaviour.

## Constraints / lessons (carry forward)

- Audit packaging repos against **GitHub remotes / fresh clones**, never
  the stale local `repos/*`.
- A green Update-workflow run ≠ a correct bump — check the repo's CI run.
- Any edit to `repo-standard/update.sh|update.yml` requires re-syncing all
  21 repos — batch edits, sync once.
- `nix eval` of a full `toplevel` triggers `lmstudio-nix` IFD installer
  downloads — verify config changes with a narrow option eval instead
  (see memory `lmstudio-ifd-eval-downloads`).
- `nix flake check` can false-fail on stale `references.nix.drv` — verify
  via direct `toplevel.drvPath` eval (memory `nix-flake-check-stale-refs`).
- The `typos` pre-commit hook flags acronyms — spell things out.
- `deps/default.nix` (eden) is a `sync-deps.py`-maintained lockfile;
  registering a new dep once makes it auto-maintained — not a band-aid.

---
title: "Session handoff — packaging-updater overhaul"
type: handoff
created: 2026-05-19
updated: 2026-05-19 (session 3)
---

# Session handoff — 2026-05-19 packaging overhaul

Three sessions of work on the `2026-05-19-001-nix-packaging-updater-overhaul`
spec. The spec (`docs/specs/2026-05-19-001-nix-packaging-updater-overhaul.md`)
holds the full design + per-session execution log; this handoff is the
authoritative session-level state. **Read both before continuing.**

The packaging standard lives in `<nix-repo>/repo-standard/` and is synced into
each `repos/*-nix` packaging repo (each its own gitignored independent git
repo under `github.com/Daaboulex`).

---

## TL;DR — state at session-3 power-off

- Main `nix` repo `Daaboulex/nixos@main`: HEAD is the **handoff commit** below.
  `e0e040a` and the handoff commit are pushed (this session ends with a clean,
  fully-pushed tree). Pre-session-3 HEAD was `806802b`.
- `repo-standard/` is hardened (all post-review-audit HIGH/MEDIUM/LOW items
  fixed) and **all 21 packaging repos are re-synced to it** — drift-check
  green on all 21.
- **eden-nix PR #10 (SDL3 migration) is MERGED** to eden `main` (`90dd284`).
- **Open at power-off:** 5 fleet repos still had CI builds in flight (heavy
  compiles — all expected green). First action next session: re-poll them.

---

## Done — sessions 1 & 2 (already complete, for context)

- **Wave 1–2:** created the canonical `repo-standard/` (`update.sh` v2,
  `update.yml`, `drift-check.yml`, `sync.sh`, `update.schema.json`,
  `README.md`); migrated all 21 repos' `update.json` to v2 and synced the
  canonical scripts/workflows.
- **Wave 3 — drift cleared:** lsfg-vk, portmaster, coolercontrol bumped;
  openviking ported 0.2.10→**0.3.17** (Go AGFS → Rust workspace; CI green);
  eden given a bespoke `type: custom` updater (`scripts/update.sh` +
  `scripts/sync-deps.py`, verified end-to-end).
- Phase A: `repo-standard` hardening (oscillation guard, `re_esc`,
  `versionScheme: unstable-date`, `update.yml` injection hardening + the
  `${{ }}`→`env:` / `execFileSync` shell-injection fix in `806802b`).
- Phase B: fleet re-sync of those Phase-A files; lsfg-vk adopted
  `unstable-date` (`1.0.0-unstable-2026-04-25`).
- A two-reviewer audit (Codex + Claude) produced the follow-up list that
  **session 3 cleared in full** (below).

---

## Done — session 3 (this session)

### Main `nix` repo (`Daaboulex/nixos@main`) — all pushed

| Commit    | What                                                                                                              |
| --------- | ----------------------------------------------------------------------------------------------------------------- |
| `78040cf` | `feat(repo-standard)`: updater hardening + drift-check extension (see below).                                     |
| `fda5b8e` | `chore(flake)`: update packaging-repo flake inputs (user-authored lock bump).                                     |
| `e0e040a` | `docs(spec)`: third-session execution log; removed a duplicated paragraph + the stale `openviking-nix#3` pointer. |
| _(this)_  | `docs`: this handoff.                                                                                             |

**`78040cf` — repo-standard hardening (post-review-audit follow-ups):**

- `update.sh` — commit-tracked **rev detection now reads a configurable
  `revFile`** (default: `versionFile`) instead of `grep -rl 'rev = "'` across
  every `*.nix` file (which could match a bundled dependency's rev). _HIGH._
- `update.sh` — **version-write success check** now confirms the new value
  landed on the _target attr_ (`grep -P` with the read-side `(?<![A-Za-z_])`
  lookbehind), not merely somewhere in the file; the **write `sed` gained a
  `\b` left boundary** (must NOT be a `|` alternation — `|` is the `s`
  delimiter; that bug was caught + fixed mid-session). `verify.args` is
  split with `read -ra` so a multi-token value passes as separate argv. _MED._
- `drift-check.yml` — **verifies all four synced canonical files**
  (`update.sh` + the three workflows) against the canonical sha256, not just
  `update.sh`. "drift-check green" now means what it sounds like. _MED._
- `cachix.yml` — **skips when `CACHIX_AUTH_TOKEN` is missing** (a repo with
  the variable but not the secret no longer runs and fails at push). _MED._
- `update.schema.json` — `upstream` gains `additionalProperties:false` and
  **per-`type` required-field constraints** (`allOf`/`if`/`then`); new
  `revFile` property. Negative-tested: malformed configs are rejected. _MED._
- `README.md` updated for all of the above (`revFile`, drift-check scope).

### Packaging repos — all pushed

- **Fleet re-sync (Task 2):** all **21 repos** re-synced from the hardened
  canonical (`update.yml` hardened, new `cachix.yml`, extended
  `drift-check.yml`, hardened `update.sh` for the 16 non-custom repos).
  Method: fresh shallow clones from each remote into `/tmp/fleet`, `sync.sh`,
  commit + push per repo. **All 21 drift-check green.**
  - `mesa-git-nix/.github/update.json` — removed two keys the canonical
    `update.sh` ignores (`customScript`, `verify.check: "eval"`) that failed
    schema validation. No behaviour change.
- **openviking-nix** `f0340ae` — `package.nix` `postInstall` now `exit 1`
  (not `echo` warning) when `ov` / `ragfs_python*.so` are missing, so a
  packaging regression fails CI loudly. _HIGH._
- **eden-nix** `cdf412a` (on `main`) — `sync-deps.py`: an unresolved URL for
  a _tracked_ CPM dep is now a hard error (exit 1), not a warning that left
  the dep silently stale; `resolve_url`'s tag/sha branches return `None` for
  a non-GitHub `git_host` instead of building a wrong `github.com` URL. _LOW._
- **eden-nix PR #10 (SDL3 migration) — MERGED** to `main` (`90dd284`,
  branch `sdl3-migration` deleted). The SDL3-deps PR compiled clean but its
  `installPhase` failed: eden's `2026-05-18` source renamed
  `dist/72-yuzu-input.rules` → `dist/72-eden-input.rules` (de-yuzu
  branding); `package.nix` `postInstall` still used the old name. Fixed on
  the branch (`516eae0`), CI went green, merged.

---

## Verification status (session 3)

- `repo-standard/` files: `bash -n`, `shellcheck`, `actionlint`, `typos`,
  and `check-jsonschema` all clean. The schema was **negative-tested** —
  configs missing per-type required fields, or with unknown `upstream`
  properties, are rejected. The new `\b`-boundary `sed` and `grep -P`
  version-write patterns were unit-tested.
- **`revFile` change audited fleet-wide — safe, no regression.** Rev
  scoping only affects non-`version.json` commit-tracked repos: lsfg-vk
  (the only `unstable-date` repo) keeps its `rev` in its `versionFile`
  (`package.nix`) so the `revFile` default resolves correctly;
  `version.json` repos (yeetmouse, mesa) use the jq rev path;
  release-tracked repos have no `rev` to bump; cachyos-settings has no
  `rev` attr at all.
- All 21 repos: **drift-check green** (confirmed). CI: 16 green confirmed,
  5 in flight (see below).
- **Not yet exercised live:** the `update.sh` logic changes (`revFile`
  scoping, version-write check, `verify.args` split) execute only when a
  real update is detected — no Update-workflow run has exercised them yet;
  the first scheduled run per repo is the real proof. The `sync-deps.py`
  change is `py_compile`-clean + reasoned, not run against a live sync.

---

## In flight at power-off — FIRST ACTIONS NEXT SESSION

1. **Re-poll fleet CI.** At power-off, 16/21 repos' CI was green; 5 were
   still building (heavy compiles): `eden-nix`, `linux-corecycler`,
   `openviking-nix`, `portmaster-nix`, `vfio-stealth-nix`. All are expected
   green — the synced changes for `linux-corecycler`/`portmaster`/`vfio-stealth`
   touch only workflow files (not `ci.yml`'s package build); `openviking`
   builds `f0340ae` (artifacts are present, so the new `exit 1` won't fire);
   `eden-nix` builds the merged SDL3 `main` (`90dd284`) which already passed
   CI green on the PR branch. Command:
   `for r in eden-nix linux-corecycler openviking-nix portmaster-nix vfio-stealth-nix; do gh run list -R Daaboulex/$r -w CI --limit 1 --json conclusion,status; done`
   If any is **red**, read its log — it is almost certainly a _pre-existing_
   build issue unrelated to the sync (the sync did not touch `ci.yml` or any
   `package.nix` except openviking's loud-fail check).

---

## Open follow-ups (not blocking; deliberate)

1. **Task 5 — promote `repo-standard/` to its own repo**
   (`Daaboulex/nix-packaging-standard`) so projects consume it as a flake
   input. **Deferred on purpose:** doing it re-points `drift-check.yml`'s
   canonical URL and forces another full 21-repo re-sync — do it once
   `repo-standard/` is stable (it now is). Batch any further `repo-standard/`
   edits with this.
2. **`sync-deps.py` cosmetic warnings (eden-nix)** — `spirv-tools` and `mcl`
   are in `deps/default.nix` but not `cpmfile.json` (they are `CPMAddPackage`
   deps in eden's CMake, not the JSON manifest). The "POSSIBLY REMOVED"
   warning fires for them every run; correct as a warning, not an error.
3. **`nrb` intermittent "no text output" bug** — still needs a reproduction.
4. **`gemini-cli-nix`** — orphan, not wired as a flake input (the
   `gemini-cli` HM option resolves to `pkgs.llm-agents.gemini-cli`). Open
   decision: wire it in or retire the clone.
5. **`vkBasalt_overlay_wayland`** — local dir is not a git clone (no `.git`).

### Cachix — needs a user action to activate

`cachix.yml` is synced to all 21 repos but **inert** until a Cachix cache
exists. To activate: create a cache at <https://app.cachix.org>, then add a
`CACHIX_CACHE` **variable** + `CACHIX_AUTH_TOKEN` **secret** (repo or org
level). See `repo-standard/README.md`. The new `AUTH_TOKEN` guard means a
half-configured repo correctly skips instead of failing.

---

## Constraints / lessons (carry forward)

- Audit packaging repos against **GitHub remotes / fresh clones**, never the
  local `repos/*` clones — they are stale (behind origin,
  history-rewrite-diverged). `git pull` before working in any.
- **Any edit to `repo-standard/{update.sh,update.yml,drift-check.yml,cachix.yml}`
  requires re-syncing all 21 repos** — batch edits, sync once. The schema +
  README are not synced (`repo-standard/`-only).
- The fleet re-sync MUST push the new canonical to `Daaboulex/nixos@main`
  _before_ the repos' `drift-check` CI runs — drift-check fetches the
  canonical from `raw.githubusercontent.com/Daaboulex/nixos/main/repo-standard/`.
- A green Update-workflow run ≠ a correct bump — always check the repo's
  `ci.yml` CI run and the actual version after.
- `nix eval` of a full `toplevel` triggers `lmstudio-nix` IFD installer
  downloads — verify a config change with a _narrow_ option eval (memory
  `lmstudio-ifd-eval-downloads`).
- `nix flake check` can false-fail on stale `references.nix.drv` — verify via
  a direct `toplevel.drvPath` eval (memory `nix-flake-check-stale-refs`).
- The `typos` pre-commit hook flags acronyms — spell things out in
  synced/committed files.
- `check-scrub-tokens` flags local paths + "Daaboulex" outside allowlisted
  paths; `repo-standard/**` is allowlisted, `docs/` is `allow_in_docs`.
- The environment shell is **zsh** — it does NOT word-split unquoted `$VAR`.
  Loop over a string list under `bash -c '...'`, or use a zsh array.
- Subagents (incl. Codex) can write inside the cwd despite "read-only"
  instructions — `git status` after; verify Codex's claims against files.

## Cleanup

`/tmp/fleet/*` (21 fresh clones), `/tmp/eden-nix`, `/tmp/schematest`,
`/tmp/t.nix`, `/tmp/ov-src` — all ephemeral; `rm -rf` is safe and a power-off
clears `/tmp` anyway. Re-clone fresh as needed next session.

---
title: "spec: Nix Packaging Standard — Auto-Updater Overhaul"
type: spec
status: active
created: 2026-05-19
depth: deep
---

# Spec: Nix Packaging Standard — Auto-Updater Overhaul

## Problem Frame

The `repos/*-nix` packaging repos share a "Daaboulex Nix Packaging Standard"
auto-update mechanism (`scripts/update.sh` + `.github/workflows/update.yml` +
`.github/update.json`). A maintenance audit on 2026-05-19 found it structurally
unsound — packages silently drift behind upstream and nobody is alerted.

### Root findings

1. **No canonical standard exists.** `find ~/.ai-context` for
   `repo-standard` / `update.sh` / `sync.sh` returns nothing. Each repo holds
   its own copy with no master to sync from.
2. **The per-repo `update.sh` copies have diverged** — 3 distinct checksums
   across 4 sampled repos (`coolercontrol`, `portmaster`, `openviking`==`ripgrep`).
3. **`update.yml` swallows failures fleet-wide.** `EXIT_CODE=$?` runs after
   `bash scripts/update.sh | tee` — it captures `tee`'s exit (always 0), not
   update.sh's. So the "Create failure issue" step (`exit_code == '1'`) never
   fires. Every updater failure since inception has been silent. Fix:
   `EXIT_CODE=${PIPESTATUS[0]}`.
4. **Parameterized versions unreadable.** `update.sh` extracts the current
   version with `grep -oP 'version\s*=\s*"\K[^"]+'`. Repos that parameterize
   (portmaster: `portmasterVersion ? "2.1.7"` + `version = portmasterVersion;`)
   match nothing → `grep` exits 1 → `pipefail`+`set -e` kill the script before
   it sets the `updated` output → silent permanent no-op. The version _write_
   `sed` has the same blind spot.
5. **First-match version extraction is wrong for multi-component packages.**
   `grep ... | head -1` takes the first `version = "..."` literal in the file.
   openviking's `update.json` pointed `packageFile` at `package.nix`, whose
   first literal is a bundled wheel's `1.0.217` — not the package version
   (`version = "0.2.10"`, in `flake.nix`).
6. **Multi-file hashes unsupported.** `update.sh` recomputes hashes only in the
   single `packageFile`. openviking keeps `vendorHash` (Go/agfs) and
   `cargoHash` (Rust/ov-cli) in `agfs.nix` / `ov-cli.nix` — the updater can
   never reach them. The 0.2.10→0.3.17 bump fails on `agfs-0.3.17-go-modules`.
7. **Incomplete `hashes` arrays.** openviking declares `hashes: ["hash"]` but
   the package has Go + Rust components needing `vendorHash` + `cargoHash`.
8. **Dead / wrong upstream pointers.** openviking `update.json` pointed at
   `Viking-Engineering/openviking` (404; real: `volcengine/OpenViking`).
   lsfg-vk points at `Starter-Pack-Gaming/lsfg-vk` (404; real:
   `PancakeTAS/lsfg-vk`) and tracks branch `v2.0.0-dev` which is actually a tag.
9. **No multi-channel support.** Repos tracking several release lines
   (gemini-cli: stable/preview/nightly; lmstudio: stable/beta/server) are
   forced onto `type: custom` bespoke scripts — outside the standard, untested,
   unmaintained.
10. **`update.sh` commit-tracking types overwrite semantic versions with a
    raw SHA.** `github-commit` / `gitlab-commit` / `gitea-commit` set
    `LATEST_VERSION="${SHA:0:7}"` and `sed` it into `version = "..."` — wrong
    for repos whose version is a semver-ish string (lsfg-vk `2.0.0-dev25`,
    eden `0.2.0-rc2-unstable-<date>`).

### Audit caveat (process finding)

The first drift audit read the **local `repos/*` clones**, which were stale
pre-history-rewrite snapshots — it falsely flagged ~14 repos. The corrected
audit (vs GitHub remotes) found only **2 real drifts** (openviking, portmaster)
plus 2 minor (eden, lsfg-vk). Always audit against the remote / the
flake.lock-locked rev, never a local working clone.

---

## Current State — all 21 packaging repos

| Repo                                      | upstream type  | hashes declared                       | Status                                                                                            |
| ----------------------------------------- | -------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------- |
| coolercontrol-nix                         | gitlab-tag     | hash,npmDepsHash,cargoHash            | OK — auto-updates (4.3.0)                                                                         |
| models-nix                                | github-release | hash,cargoHash                        | OK — auto-updates (0.11.51)                                                                       |
| durdraw-nix                               | github-release | hash                                  | OK (0.29.0)                                                                                       |
| ripgrep-nix                               | github-release | hash,cargoHash                        | OK (15.1.0)                                                                                       |
| streamcontroller-nix                      | github-release | hash                                  | OK (1.5.0-beta.13)                                                                                |
| mullvad-vpn-nix                           | github-release | hash                                  | OK (2026.2)                                                                                       |
| mesa-git-nix                              | git-ls-remote  | hash                                  | OK — rolling                                                                                      |
| vfio-stealth-nix                          | custom         | []                                    | OK — commit pins current                                                                          |
| yeetmouse-nix                             | github-commit  | []                                    | OK — rev current                                                                                  |
| cachyos-settings-nix                      | github-commit  | []                                    | module repo — no pkg version                                                                      |
| goxlr-hm-nix / refind-nix / rocksmith-nix | none           | []                                    | module/multi-component                                                                            |
| linux-corecycler                          | none           | []                                    | own code; CI verify fixed 2026-05-19                                                              |
| lmstudio-nix                              | custom         | hash                                  | multi-channel (stable/beta/server) on bespoke script                                              |
| gemini-cli-nix                            | custom         | []                                    | multi-channel (stable/preview/nightly); **orphan — not a flake input**                            |
| OCCT-nix                                  | custom         | hash                                  | bespoke (ocbase.com)                                                                              |
| **openviking-nix**                        | github-release | hash                                  | **DRIFT 0.2.10→0.3.17** — upstream ptr fixed `27ef324`; bump blocked on multi-file hashes (#6,#7) |
| **portmaster-nix**                        | github-release | hash,vendorHash,npmDepsHash,cargoHash | **DRIFT 2.1.7→2.1.19** — blocked on parameterized version (#4)                                    |
| **lsfg-vk-nix**                           | github-commit  | hash                                  | minor drift dev25→dev26 — dead ptr (#8) + version-scheme mismatch (#10)                           |
| **eden-nix**                              | gitea-commit   | hash                                  | rc2-commit vs stable tag `v0.2.0` — tracking-strategy decision (#10)                              |
| vkBasalt_overlay_wayland                  | none           | []                                    | ⚠️ local dir is **not a git clone** (no `.git`)                                                   |

---

## Design

> **Implementation note (2026-05-19).** The design below was the _original_
> plan. Implementation deliberately simplified it (Simplicity First): there is
> **no `channels`** layer, **no `versionScheme`**; `update.json` uses flat
> top-level keys (`versionFile`, `versionAttr`, `hashes`); commit-tracked
> repos get a bare 7-char SHA as the version; and only `update.sh` +
> `update.yml` are synced (not `ci.yml`/`maintenance.yml`). The **Execution
> Log** and the actual `repo-standard/` files are the source of truth for
> what was built — read the Design as rationale, not as the shipped schema.

### D1. Canonical home: `<nix-repo>/repo-standard/`

The standard lives **in this nix repo**, not under the `.ai-context` symlink
(that points into the shared global `~/.ai-context`, mutated by other sessions,
and is the wrong owner for project tooling). New directory:

```
repo-standard/
  update.sh            # canonical updater v2
  update.yml           # canonical Update workflow
  ci.yml               # canonical CI workflow
  maintenance.yml      # canonical maintenance workflow
  update.schema.json   # JSON Schema for update.json v2
  sync.sh              # pushes canonical files into each repos/*-nix clone
  README.md            # the standard, documented
```

`sync.sh` copies the canonical files into every `repos/*-nix` and reports
diffs; repos commit + push individually. A CI check in each repo verifies its
copy matches the canonical checksum (drift-prevention — finding #2).

### D2. `update.json` schema v2

Replace the flat `packageFile` + `hashes: [string]` with explicit, multi-file,
multi-channel structure:

```jsonc
{
  "package": "openviking",
  "channels": {
    // one or more release lines
    "default": {
      "upstream": {
        "type": "github-release",
        "owner": "volcengine",
        "repo": "OpenViking",
      },
      "version": { "file": "flake.nix", "attr": "version" },
      "hashes": [
        // ordered: source first, then vendor
        { "field": "hash", "file": "flake.nix" },
        { "field": "vendorHash", "file": "agfs.nix" },
        { "field": "cargoHash", "file": "ov-cli.nix" },
      ],
    },
  },
  "verify": { "binary": null, "check": "wrapper" },
}
```

- `version.attr` — the _attribute name_ to match, so `version = "X"`,
  `version ? "X"`, and `portmasterVersion ? "X"` are all addressable
  (resolves finding #4 and #5 — no more first-`version=` guessing).
- `hashes[].file` — per-hash file, so vendor hashes in sub-`.nix` files are
  reachable (finding #6).
- `channels` — multiple named release lines, each with its own upstream +
  version + hashes (finding #9). Single-channel repos use one `default`.
- Back-compat: a v1→v2 migration step (Wave 2) converts every repo.

### D3. `update.sh` v2 — capabilities

1. **Version read** — regex `^\s*<attr>\s*[?=]\s*"<capture>"` driven by
   `version.attr`; matches literal _and_ parameterized forms.
2. **Version write** — `sed` that preserves the `attr [?=] ` prefix and swaps
   only the quoted value.
3. **Per-channel loop** — process each channel independently; a channel
   failure does not abort siblings.
4. **Multi-file hashes** — iterate `hashes[]`, operate on each `.file`,
   dependency-ordered (source → vendor).
5. **Version-scheme awareness** — for commit-tracked types, write the version
   as `<base>-unstable-<date>` (nixpkgs convention) or keep a `versionTemplate`
   from `update.json`, never a bare SHA (finding #10).
6. **Strict-mode safety** — every `grep|head` guarded with `|| true`; never let
   a no-match silently kill the script.
7. **Exit contract** unchanged: 0 = ok/no-op, 1 = failed, 2 = network.

### D4. `update.yml` v2

- `EXIT_CODE=${PIPESTATUS[0]}` (finding #3).
- Per-channel outputs so multi-channel repos commit each channel's bump.
- Keep silent-success / failure-issue / auto-close behavior.

### D5. Multi-version / multi-branch support (explicit requirement)

Channels formalize this. Target configuration:

| Repo           | Channels                                                     |
| -------------- | ------------------------------------------------------------ |
| gemini-cli-nix | stable · preview · nightly                                   |
| lmstudio-nix   | stable · beta · server                                       |
| portmaster-nix | stable (`portmaster`) · testing (`portmaster-testing`)       |
| eden-nix       | stable (`v*` tags) · dev (master commits) — decision pending |
| lsfg-vk-nix    | dev (`PancakeTAS/lsfg-vk` `develop`) — decision pending      |

---

## Execution Waves

**Wave 1 — Canonical standard.** Create `repo-standard/` with updater v2,
workflows, `update.schema.json`, `sync.sh`, `README.md`. Self-test update.sh v2
against fixture `update.json`s for each upstream type. _Verify:_ `bash -n`,
schema validates, fixtures pass.

**Wave 2 — Migrate `update.json` v1→v2 + re-sync.** Per repo: author the v2
`update.json` (correct upstream, version attr, per-file hashes, channels);
`sync.sh` the canonical scripts/workflows in; commit + push per repo.
_Verify:_ each repo's Update workflow dry-run detects the correct current
version and (where drifted) the correct latest.

**Wave 3 — Clear the real drift.** openviking 0.2.10→0.3.17, portmaster
2.1.7→2.1.19, lsfg-vk dev25→dev26, eden→v0.2.0 — driven by the now-correct
updater (CI does the hash recompute + build). Each lands as a normal Update
commit or a visible `update-failed` issue.

**Wave 4 — Standards docs.** Update `docs/STYLE.md` / `docs/DEVELOPMENT.md`
and `repo-standard/README.md` with the v2 schema and the updater contract.
Add the per-repo `ci.yml` check that the repo's standard files match the
canonical checksum.

**Wave 5 — Loose ends.** `vkBasalt_overlay_wayland` re-clone as a real git
repo; decide gemini-cli-nix (wire in as a flake input, or retire the clone).

---

## Open Decisions (need user input)

- **eden-nix**: track upstream _stable tags_ (`v0.2.0`) or _master commits_?
  Determines channel config.
- **lsfg-vk-nix**: package version stays a semantic `2.0.0-devNN` string —
  who assigns `NN`? If upstream has no matching tag, use
  `2.0.0-dev-unstable-<date>` and a commit channel.
- **gemini-cli-nix**: wire in as a flake input, or retire the orphan clone
  (the `gemini-cli` HM option already resolves to `pkgs.llm-agents.gemini-cli`).
- **Canonical-standard sync direction**: `repo-standard/` here is the master;
  confirm the `custom`-type repos (OCCT, vfio-stealth) keep bespoke updaters
  documented as sanctioned exceptions.

---

## Verification / Done Criteria

- A single canonical `repo-standard/` exists; every `repos/*-nix` copy matches
  it by checksum (CI-enforced).
- `update.json` validates against `update.schema.json` in every repo.
- Every repo's Update workflow, dry-run, reports the correct current version.
- openviking + portmaster are at upstream latest; no open `update-failed`
  issues except sanctioned ones.
- `update.yml` failure-issue path proven to fire on an induced failure.
- `docs/STYLE.md` + `repo-standard/README.md` document the v2 standard.

---

## Execution Log — 2026-05-19

**Wave 1 — done.** `repo-standard/` created (`update.sh` v2, `update.yml`,
`sync.sh`, `README.md`). update.sh v2 handles parameterized versions _and_
hashes (`<attr> ? "x"`), multi-file `{field,file}` hash placement, and uses
a dummy-all + iterative build-fail-parse extractor (a version bump
invalidates every FOD hash at once, so per-field dummying was unsound).
`update.yml` uses `EXIT_CODE=${PIPESTATUS[0]}`.

**Wave 2 — done.** All 21 package repos synced onto the canonical
`update.sh` + `update.yml` and pushed. `custom`-type repos kept their
bespoke `update.sh` (canonical `update.yml` only).

**Wave 3 — partial.**

- `lsfg-vk-nix` — ✅ bumped. `update.json` owner `Starter-Pack-Gaming`→
  `PancakeTAS`, branch `v2.0.0-dev` (a tag)→`develop`.
- `eden-nix` — updater now _functional_ (`update.json` `branch: master` —
  eden's default branch; the `gitea-commit` default `main` 404'd). Bump
  still fails: eden bundles ~25 CPM dependencies in `deps/default.nix`,
  each with its own hash, and many change when eden's commit bumps. The
  generic updater cannot regenerate them. **Follow-up: eden needs a
  bespoke `update.sh` (`type: custom`) that re-derives `deps/default.nix`
  from eden's CPM manifest.** Until then the failure is visible as a
  persistent `update-failed` issue.
- `openviking-nix` / `portmaster-nix` — migrated to updater v2
  (`update.json` v2: corrected upstream, `versionAttr`, per-file hashes).
  Re-triggered with the iterative extractor; both still fail the bump:
  - openviking — `agfs-0.3.17-go-modules` will not build (a real Go
    vendoring failure at the new version, not a hash mismatch).
  - portmaster — hash extraction does not converge: the build exposes
    more distinct FODs than the declared hash fields.
    Both — like eden — are complex multi-language packages with nested /
    undeclared FODs that the generic updater cannot bump. **The three
    (openviking, portmaster, eden) need bespoke per-repo update logic.**
    Their drift is now visible as persistent `update-failed` issues — the
    silent-drift problem is solved even though these three are not yet
    auto-bumping. The common case is proven: lsfg-vk bumped end-to-end.

**Also done:** flake input owner casing normalized
(`github:daaboulex/`→`Daaboulex/`, 5 inputs). `update.schema.json` added.
`sync.sh` made project-agnostic (`PKG_REPOS_DIR`, no hardcoded paths).

### Finding 11 — the old updater pushed _broken_ bumps (not just silent)

coolercontrol-nix's CI was red: `flake.nix` had `npmDepsHash` **and**
`cargoHash` set to the _same_ value. The old per-field extractor's
`head -1 got:` took the hash from the wrong fixed-output derivation, and
the `$?`-vs-`PIPESTATUS` bug let the failed verification push anyway — so
a broken 4.3.0 landed on `main`. Fixed (`ff27aea`): `npmDepsHash`
corrected to the value CI reported; `cargoHash` (`f0Ss…`) was already
right. The v2 extractor (drv-name→field mapping) + the PIPESTATUS fix
prevent recurrence. Lesson: a green `Update` run never meant a correct
bump — always confirm CI after.

### Fleet CI audit (2026-05-19)

20 of 21 repos green or freshly green; **coolercontrol** was the one red
(fixed above). openviking/portmaster/eden remain blocked on bespoke work.

### Drift resolution — final

- **lsfg-vk** ✅ bumped (updater fix + `update.json` owner/branch).
- **portmaster** ✅ bumped 2.1.7→2.1.19 (parameterized-version +
  cargo `vendor-staging` extractor fixes).
- **coolercontrol** ✅ CI green (npmDepsHash corrected — `ff27aea`).
- **openviking / eden** — blocked on focused packaging work, below.

Every drift the updater _can_ fix is fixed; the rest is genuine
repackaging, precisely scoped here.

**Still open — focused follow-ups:**

- **openviking 0.3.17 port** — a major upstream restructure. 0.3.17 is a
  unified Rust Cargo workspace (`crates/{ov_cli,ragfs,ragfs-python}`);
  `ragfs` is the Rust rewrite of the old Go AGFS. Port plan: delete
  `agfs.nix` (`buildGoModule`, obsolete); build the Cargo workspace
  (single `cargoHash`, no more Go `vendorHash`); `ragfs-python` is
  PyO3/maturin; rework `package.nix`'s prebuilt-dep copying. ~3-4 `.nix`
  files; needs iterative local builds.
- **eden bespoke updater** — `deps/default.nix` carries ~25 CPM
  dependency hashes that change with eden's commit; needs a
  CPM-manifest-aware `update.sh` (`type: custom`).
- **CI drift-check** — a `ci.yml` step per repo comparing `update.sh`
  against the canonical (`raw.githubusercontent.com/.../repo-standard/`).
- Promote `repo-standard/` to its own repo once stabilised, so other
  projects consume it as a flake input (single source of truth).
- `vkBasalt_overlay_wayland` local clone has no `.git` (cosmetic).

---

## Execution Log — 2026-05-19 (continuation session)

### Phase A — repo-standard hardening (done)

Canonical-side fixes from the Codex review. Commits `ec289b5`, `2082549`
on `Daaboulex/nixos@main`.

- **`update.sh` hash oscillation guard.** An undeclared fixed-output
  derivation used to be misrouted onto the source `hash` field; the
  extractor then looped silently to the convergence cap. A new
  `HF_DONE` map detects a mismatch re-routed onto an already-resolved
  field and fails immediately with `undeclared hash for derivation X`.
- **`update.sh` regex escaping.** New `re_esc` helper escapes
  `VERSION_ATTR` and hash field names before they are interpolated into
  `grep -P` / `sed`.
- **`update.sh` versionScheme.** New `versionScheme: "unstable-date"`:
  commit-tracked repos can write `<versionBase>-unstable-<YYYY-MM-DD>`
  (orderable by `compareVersions`) instead of a bare SHA; update
  detection compares the `rev`. Default `literal` keeps the old
  behaviour. Schema gains `versionScheme` + `versionBase`.
- **`update.yml` injection hardening.** The two `github-script` steps no
  longer interpolate `${{ }}` outputs into the JS body — values pass via
  `env:` and `process.env`.
- **`drift-check.yml`** (new canonical workflow, synced to every repo):
  CI fails if `scripts/update.sh` diverges from the canonical (sha256 vs
  `raw.githubusercontent.com/Daaboulex/nixos/main/`); `custom`-type
  repos are skipped. This is Task 4 (CI drift-check) — implemented as a
  standalone synced workflow rather than a per-repo `ci.yml` edit.

Verified: `bash -n`, `shellcheck`, `actionlint`, `typos` all clean.

### Phase B — fleet re-sync (done)

All 21 packaging repos re-synced from the new canonical. Method: shallow
clones from each remote into `/tmp/fleet/` (the local `repos/*` clones
are stale — never synced from), `sync.sh`, commit + push per repo. All
21 **drift-check green** (sync is byte-correct) and all 21 **CI green**.

- **lsfg-vk** opted into `versionScheme: "unstable-date"`. `versionBase`
  is `1.0.0` — PancakeTAS/lsfg-vk's latest _stable_ release (`v2.0.0-dev`
  is a pre-release tag; `2.0.0-unstable-X` would wrongly sort newer than
  a future `2.0.0` via the empty-vs-string `compareVersions` gotcha).
  `package.nix` version is now `1.0.0-unstable-2026-04-25` (dated to the
  pinned commit `218820e`).

### openviking-nix 0.3.17 port — investigation complete, plan below

Upstream 0.3.17 (`volcengine/OpenViking`) restructured: AGFS is no longer
a Go server. The Cargo workspace (`crates/`) has three members:

- `ov_cli` — binary `ov` (Rust CLI; unchanged role).
- `ragfs` — lib + binaries `ragfs-server`, `ragfs-shell` (the Rust
  rewrite of the Go AGFS). features: `default=[]`, `s3`, `full`.
- `ragfs-python` — PyO3 `cdylib` `ragfs_python`, `abi3-py310`,
  `build-backend = maturin`. Replaces the old CGO `libagfsbinding.so`.

`third_party/agfs` is gone; `third_party/` now holds only C++ vector-
engine deps (croaring, krl, leveldb, rapidjson, spdlog).

**How the Python build (`setup.py`) consumes the native parts:**

- `ov` — honoured via `OV_PREBUILT_BIN_DIR` env (copy `$DIR/ov` →
  `openviking/bin/ov`, skip cargo). Same mechanism as 0.2.10.
- `ragfs_python` — `build_ragfs_python_artifact()` runs `maturin`, extracts
  `ragfs_python.abi3.*.so` into `openviking/lib/`. **Gotcha:**
  `_should_require_ragfs_artifact()` returns True when `bdist_wheel` is in
  `sys.argv` — which `buildPythonApplication` always does. So
  `OV_SKIP_RAGFS_BUILD=1` alone raises. The package.nix MUST also set
  `OV_REQUIRE_RAGFS_BUILD=0`, then pre-place `ragfs_python.abi3.so` in
  `openviking/lib/` (bundled via the `lib/ragfs_python*.so` package-data
  glob).
- C++ vector engine — cmake build of `src/`, same as 0.2.10, but the SIMD
  var changed: `OV_X86_SIMD_LEVEL` → `OV_X86_BUILD_VARIANTS` (default
  `sse3;avx2;avx512`, multi-variant + runtime dispatch).

**Port plan (per file in openviking-nix):**

1. Delete `agfs.nix`.
2. `ragfs.nix` (new) — `rustPlatform.buildRustPackage`, `-p ragfs`,
   builds `ragfs-server` + `ragfs-shell`. Standalone package (the
   `openviking` package does not need it — AGFS runs in-process via
   `ragfs_python`).
3. `ragfs-python.nix` (new) — maturin build of `crates/ragfs-python`,
   producing the `ragfs_python.abi3.so` extension.
4. `ov-cli.nix` — unchanged shape; new `cargoHash` for 0.3.17.
5. `flake.nix` — version `0.3.17`, new src hash; the three crates share
   one root `Cargo.lock` ⇒ a single shared `cargoDeps`
   (`rustPlatform.fetchCargoVendor`) referenced by all Rust builds — one
   `cargoHash` for the repo. Packages: `default=openviking`, `ov-cli`,
   `ragfs`. Drop `agfs`.
6. `package.nix` — `OV_PREBUILT_BIN_DIR` for `ov`; pre-place
   `ragfs_python*.so` + `OV_SKIP_RAGFS_BUILD=1` + `OV_REQUIRE_RAGFS_BUILD=0`;
   keep the cmake C++ engine build; refresh the dependency list to
   0.3.17's `pyproject.toml` (~60 runtime deps — many new:
   `opentelemetry-*`, `argon2-cffi`, `lark-oapi`, `mcp`, `pathspec`,
   `tree-sitter-php`, `tree-sitter-lua`; tree-sitter grammars not in
   nixpkgs still come from pre-built wheels).
7. `update.json` — drop the `vendorHash` entry (it pointed into
   `agfs.nix`); `hashes` becomes source `hash` + the single shared
   `cargoHash`, both in `flake.nix`.

**Progress (this session):** `flake.nix`, `ov-cli.nix`, `ragfs-python.nix`,
`package.nix` written in a fresh clone; `agfs.nix` deleted; `update.json`
updated (hashes now `hash` + `cargoHash`, both in `flake.nix`). Hashes
resolved — src `sha256-wJuC5pN3+pMiq4rCNoUeXjO0lWFn6sejMJ6ml0TXf8s=`,
workspace cargo `sha256-Pv9TeE9c/U46ScI40FHwvXjeYZ7/D3N03pYXEU+uIPQ=`.

**Remaining (iterative builds):** build `ov-cli` + `ragfs-python`; map the
full 0.3.17 Python dependency closure against nixpkgs (the new
`package.nix` dep list is a first cut — `lark-oapi`,
`opentelemetry-instrumentation-*`, `tree-sitter-php`/`-lua` may be missing
from nixpkgs and need wheels); build the C++ engine + maturin extension.
Not yet committed/pushed at the time of this note — superseded by the
Resolution section below: the 0.3.17 port shipped (`openviking-nix@e80ca15`)
and the tracking issue is closed.

### eden-nix bespoke updater — investigation

The generic updater bumps eden's `version`/`rev`/src `hash` but cannot
touch `deps/default.nix` (~23 pre-fetched CPM dependencies). Investigation
found the dependency manifest is **split**, which is worse than the
original framing assumed:

- `cpmfile.json` (eden master) has only **12 entries**, and they are
  almost all the system libraries eden-nix already takes from nixpkgs
  (`openssl`, `boost`, `fmt`, `lz4`, `nlohmann`, `zlib`, `zstd`, `opus`,
  `boost_headers`, plus Windows-only `llvm-mingw` and
  `vulkan-validation-layers`). Only `quazip` overlaps `deps/default.nix`.
- The other ~22 bundled deps (`xbyak`, `enet`, `mbedtls`, `simpleini`,
  `cubeb`, `discord-rpc`, `spirv-headers`/`-tools`, `sirit`, `vma`,
  `unordered-dense`, `gamemode`, `vulkan-headers`/`-utility-libraries`,
  `frozen`, `mcl`, `libusb`, `nx-tzdb`, `oaknut`, `httplib`, `cpp-jwt`)
  are declared as classic `CPMAddPackage(...)` calls in eden's CMake
  files (`externals/CMakeLists.txt` and friends) — **not** in
  `cpmfile.json`.
- `package.nix`'s `preConfigure` additionally hardcodes the CPM-cache
  version path per dep (`copyDep ${deps.cubeb} cubeb/fa02`,
  `xbyak/7.35.2`, …) — those paths are coupled to each dep's ref and must
  be regenerated in lockstep with `deps/default.nix`.
- Refs come in three URL shapes: GitHub release tags
  (`/archive/refs/tags/<tag>.tar.gz`), GitHub commit SHAs
  (`/archive/<sha>.tar.gz`), and `git.eden-emu.dev` Gitea release
  artifacts (`sirit`, `nx-tzdb`).

So a correct `type: custom` `scripts/update.sh` must parse **both**
`cpmfile.json` and the CMake `CPMAddPackage` calls, prefetch a Nix SRI
hash per bundled dep, and rewrite `deps/default.nix` **and** the
`preConfigure` cache paths in `package.nix`.

### Resolution — 2026-05-19 (continuation)

**openviking** — port pushed (`openviking-nix@e80ca15`); CI builds the
0.3.17 package green. Update-failed issue closed. **Done.**

**eden** — eden-nix already shipped `scripts/sync-deps.py`, a tool that
re-derives `deps/default.nix` + `package.nix` CPM paths from
`cpmfile.json` (+ an `EXTRA_DEPS` table for GitHub-release deps). The gap
was that nothing drove it. Resolution:

- `scripts/update.sh` rewritten as the bespoke `type: custom` updater
  (`eden-nix@3a4af39`): Gitea-API commit detection, date-stamped version
  (`<base>-unstable-<date>`), `sync-deps.py` orchestration, source-hash
  recompute, full verify. `update.json` set to `type: custom`.
- `sync-deps.py` `SKIP_KEYS` fixed (`eden-nix@668c014`) — upstream moved
  the nixpkgs-satisfied system libs (openssl/boost/fmt/zlib/zstd/opus/…)
  into `cpmfile.json`; they must be skipped, not bundled.
- The updater is **verified working end-to-end** via a dispatched Update
  run: it bumped, re-derived deps, recomputed the hash, and the build
  then failed on a _genuine upstream change_ — eden `2026-05-18` migrated
  **SDL2 → SDL3**, which it only provides via CPM (no system path). That
  is a focused repackaging follow-up (bundle `sdl3` in `deps/default.nix`
  - `preConfigure`, drop system SDL2), tracked on `eden-nix` issue #9.
    The bespoke updater itself is complete — silent drift is now a
    visible, precisely-diagnosed failure.

---

## Execution Log — 2026-05-19 (third session)

### Review follow-ups — repo-standard hardening (done)

The post-review audit's HIGH/MEDIUM canonical-side findings, fixed in one
batch (`Daaboulex/nixos@main`, then re-synced fleet-wide):

- **`update.sh` rev scoping** — `unstable-date` rev detection and the
  commit-tracked rev write no longer `grep -rl 'rev = "'` across every
  `*.nix` file (which could match a bundled dependency's rev). Both read a
  configurable `revFile` (default: `versionFile`).
- **`update.sh` version-write** — the success check now confirms the new
  value landed on the target attr (`grep -P` with the read-side
  lookbehind) instead of matching the literal anywhere in the file; the
  write `sed` gained a `\b` left boundary (not a `|` alternation — `|` is
  the `s` delimiter) so a short attr cannot match a longer identifier's
  tail. `verify.args` is split with `read -ra` so a multi-token value is
  passed as separate argv entries.
- **`drift-check.yml`** — verifies all four synced canonical files
  (`update.sh` + the three workflows) against the canonical sha256, not
  just `update.sh`. "drift-check green" now means what it sounds like.
- **`cachix.yml`** — skips when `CACHIX_AUTH_TOKEN` is missing, so a repo
  with the variable but not the secret no longer runs and fails at push.
- **`update.schema.json`** — `upstream` gains `additionalProperties:false`
  and per-`type` required-field constraints; new `revFile` property.
  Validated against the live fleet `update.json`s.

### Fleet re-sync (done)

`cachix.yml` (opt-in binary cache) and the hardened `update.yml` +
`drift-check.yml` + `update.sh` distributed to all 21 repos via
`sync.sh` over fresh remote clones. All 21 **drift-check green**.
`mesa-git-nix`'s `update.json` had two keys the canonical `update.sh`
ignores (`customScript`, `verify.check: "eval"`) that failed schema
validation — removed (no behaviour change).

### Other audit follow-ups (done)

- **openviking-nix** `package.nix` `postInstall` — the `ov` /
  `ragfs_python*.so` presence checks `exit 1` instead of `echo`ing a
  warning, so a packaging regression fails CI loudly.
- **eden-nix** `sync-deps.py` — an unresolved URL for a _tracked_ CPM dep
  is now a hard error (exit 1), not a warning that left the dep silently
  stale; `resolve_url`'s tag/sha branches return `None` for a non-GitHub
  `git_host` rather than building a wrong `github.com` archive URL.

### eden SDL3 migration (PR #10)

eden `2026-05-18`'s SDL2→SDL3 move: the SDL3 deps PR compiled clean but
`installPhase` failed — eden renamed `dist/72-yuzu-input.rules` →
`dist/72-eden-input.rules` as part of de-yuzu branding; `package.nix`
`postInstall` still referenced the old name. Fixed on the branch.

---

## Session 4 — 2026-05-20 (closeout)

### Task 5 — `repo-standard/` promoted to its own repo (done)

The canonical standard now lives at
**[github.com/Daaboulex/nix-packaging-standard](https://github.com/Daaboulex/nix-packaging-standard)**
(initial commit `b76366d`).

- `drift-check.yml` `BASE` URL re-pointed:
  `raw.githubusercontent.com/Daaboulex/nix-packaging-standard/main/`
  (no `/repo-standard/` path segment — files are at repo root now).
- `sync.sh` takes `PKG_REPOS_DIR` explicitly (was implicit
  `<parent-of-repo-standard>/repos`) so the standard is genuinely repo-agnostic.
- `repo-standard/` directory **deleted** from main `nixos` repo.
- All 21 packaging repos re-synced + pushed in one wave; drift-check CI
  confirmed green against the new URL on every repo's just-pushed HEAD.

### Cachix removed (done)

Free-tier (5 GB storage / 50 GB/mo bandwidth) is too small for the fleet
(mesa-git, eden, portmaster, kernel, electron apps); remote builders cover
cross-machine rebuilds; the inert `cachix.yml` added 21 files + a
drift-check entry without payoff.

- `cachix.yml` dropped from the canonical set (`sync.sh` + `drift-check.yml`
  FILES maps no longer include it).
- `.github/workflows/cachix.yml` `git rm`'d in each of the 21 packaging repos.
- README's Cachix section removed.

Re-introduce if a paid binary cache ever lands — restoration is a single
`cachix.yml` add + `sync.sh` FILES-map entry + 21-repo re-sync.

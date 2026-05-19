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

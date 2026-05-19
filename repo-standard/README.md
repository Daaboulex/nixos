# Nix Packaging Standard — `repo-standard/`

Canonical source of the shared tooling used by every `repos/*-nix` packaging
repo. **This directory is the single source of truth.** Per-repo copies are
synced from here by `sync.sh`; never edit a per-repo copy directly.

History: prior to 2026-05-19 there was no canonical copy — each repo carried
its own `update.sh`, and the copies silently diverged (3+ variants). See
`docs/specs/2026-05-19-001-nix-packaging-updater-overhaul.md` for the full
audit and design.

## Files

| File                 | Synced to (per repo)                | Purpose                              |
| -------------------- | ----------------------------------- | ------------------------------------ |
| `update.sh`          | `scripts/update.sh`                 | Detect + apply upstream updates      |
| `update.yml`         | `.github/workflows/update.yml`      | Scheduled Update workflow            |
| `drift-check.yml`    | `.github/workflows/drift-check.yml` | CI: synced files match the canonical |
| `cachix.yml`         | `.github/workflows/cachix.yml`      | Opt-in Cachix binary-cache push      |
| `update.schema.json` | _(not synced — reference)_          | JSON Schema for `update.json`        |
| `sync.sh`            | _(not synced — run from here)_      | Push canonical files into repos      |
| `README.md`          | _(this file)_                       | The standard, documented             |

## `sync.sh`

```bash
repo-standard/sync.sh            # sync canonical files into all repos
repo-standard/sync.sh coolercontrol-nix portmaster-nix   # named repos
repo-standard/sync.sh --check    # report drift only, exit 1 if any
```

Each repo commits + pushes its own changes. The synced `drift-check.yml`
workflow fails CI if any synced file (`scripts/update.sh` + the three
canonical workflows) diverges from the canonical — it compares each file's
sha256 against
`raw.githubusercontent.com/Daaboulex/nixos/main/repo-standard/`
(`custom`-type repos keep a bespoke `update.sh` and skip that one file). Run
`sync.sh --check` for the same check locally.

## `.github/update.json` schema

```jsonc
{
  "package": "openviking",            // package / repo name
  "upstream": { "type": "...", ... }, // see upstream types below
  "packageFile": "package.nix",       // file `nix build .#default` centers on
  "versionFile": "flake.nix",         // file holding the canonical version
                                      //   literal (default: packageFile)
  "versionAttr": "version",           // attribute name to match (default
                                      //   "version"; e.g. "portmasterVersion")
  "revFile": "package.nix",           // file holding the src `rev` literal
                                      //   (default: versionFile)
  "versionScheme": "unstable-date",   // optional; "literal" (default) or
                                      //   "unstable-date" (commit-tracked)
  "versionBase": "2.0.0",             // base for "unstable-date" (optional)
  "hashes": [                         // SRI hash fields, dependency order:
    "hash",                           //   bare name -> auto-located, or
    { "field": "vendorHash",          //   {field,file} to disambiguate when
      "file": "agfs.nix" }            //   a name appears in several files
  ],
  "verify": { "binary": null, "check": "wrapper" }
}
```

- **`versionAttr`** matches both `version = "x"` and parameterized
  `<attr> ? "x"` default-argument forms — so `portmasterVersion ? "2.1.7"`
  works with `"versionAttr": "portmasterVersion"`.
- **`versionFile`** decouples the version literal's location from
  `packageFile` (e.g. the literal lives in `flake.nix` while `package.nix`
  only takes it as an argument).
- **`revFile`** scopes the `rev` literal bump for commit-tracked upstreams
  (defaults to `versionFile`). Set it explicitly when a repo carries
  several `rev = "..."` literals — e.g. a bundled dependency's `rev` — so
  the updater bumps the package's own src `rev`, not a dependency's.
- **`hashes`** entries list SRI hash fields in evaluation-dependency order
  (source hash first, then vendor hashes). Each entry is either a bare field
  name — auto-located in the first `*.nix` file declaring it — or
  `{"field","file"}` to disambiguate when a name like `hash` appears in
  several files (source `hash` in `flake.nix` vs bundled-wheel `hash`s in
  `package.nix`).
- For commit-tracked packages prefer **`versionFile: "version.json"`**: the
  updater writes `{version, rev, date}` cleanly instead of clobbering a
  semantic version string with a bare SHA.
- **`versionScheme`** controls the written version literal. `literal`
  (default) writes the upstream string verbatim — a bare 7-char SHA for
  commit-tracked types. `unstable-date` writes
  `<versionBase>-unstable-<YYYY-MM-DD>` (the nixpkgs VCS-snapshot
  convention, orderable by `builtins.compareVersions`); the `rev` attr
  still tracks every commit, and update detection compares the `rev`, not
  the date string. `unstable-date` is valid only for commit-tracked
  upstream types.
- **`versionBase`** is the base prefix for `unstable-date` (e.g. the last
  release tag, `"2.0.0"`). If omitted, it is derived by stripping any
  `-unstable-*` suffix from the current version.

### Upstream types

`github-release` · `github-tag` · `github-commit` · `gitlab-tag` ·
`gitlab-commit` · `gitea-commit` · `git-ls-remote` · `none` · `custom`

`none` — module/multi-component repos with nothing to track.
`custom` — the repo ships its own `scripts/update.sh` (multi-channel apps
such as gemini-cli stable/preview/nightly, or non-API sources like OCCT).
Custom repos are sanctioned exceptions: the canonical `update.sh` exits 0
early for them; their bespoke script must honour the same exit contract.

## `update.sh` contract

- **exit 0** — no update needed, or update applied + verified.
- **exit 1** — a real failure (config, version read/write, hash extraction,
  build, verification) → workflow opens an `update-failed` issue.
- **exit 2** — network / API error → no issue, retried next run.
- Outputs (to `$GITHUB_OUTPUT`): `updated`, `old_version`, `new_version`,
  `package_name`, `upstream_url`, `error_type`.
- Flow: read version → fetch upstream → compare → write version (+ rev) →
  extract each hash (build-fail-parse) → verify (eval → build → artifact).

## `update.yml` behaviour

- Success → silent commit + push to the default branch.
- Failure (`exit 1`) → `update-failed` issue with the build log + a recovery
  branch; previous failure issues auto-close on the next success.
- `EXIT_CODE=${PIPESTATUS[0]}` captures `update.sh`'s real exit — **not**
  `tee`'s. (The historic `$?` bug silently swallowed every failure.)

## Cachix (optional binary cache)

`cachix.yml` pushes a repo's `.#default` build to a [Cachix](https://cachix.org)
cache on every push to the default branch, so other CI runs and the consuming
nixos config get binary-cache hits instead of recompiling. It is **opt-in and
inert by default** — the job no-ops unless the repo (or the org) defines the
configuration below, and module-only repos (no `.#default`) skip automatically.

One-time setup, per repo or once at the org level:

1. Create a cache at <https://app.cachix.org> (one shared cache for all the
   packaging repos is the simplest layout).
2. Add a **variable** `CACHIX_CACHE` = the cache name.
3. Add a **secret** `CACHIX_AUTH_TOKEN` = a write token
   (`cachix authtoken` from the cache's settings).

To consume the cache, add it as a substituter in the nixos config:

```nix
nix.settings = {
  substituters = [ "https://<cache-name>.cachix.org" ];
  trusted-public-keys = [ "<cache-name>.cachix.org-1:<public-key>" ];
};
```

`cachix.yml` is synced like the other canonical workflows; it carries no
secrets and is safe to ship to every repo whether or not Cachix is configured.

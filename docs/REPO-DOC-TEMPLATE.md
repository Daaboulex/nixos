# Daaboulex Nix Packaging Repo — Documentation Template v1.0

Documentation shape contract for `repos/*-nix` satellite flakes. Pairs with
`docs/REPO-STANDARD.md` (file/CI/flake contract). Both apply.

Version 1.0 (2026-04-24). Derived from the post-restructure state of the
main nix flake's own `docs/` and from surveying all 20 satellite repos.

## Why a doc template

The 20 `repos/*-nix` README files drifted into 20 different shapes —
"What Is This?" vs "Overview" vs "Why?" vs "Features", attribution buried
mid-document or omitted, license sections missing in half. A reader
landing on a random repo could not predict where to find install steps
or upstream credit.

This template fixes the section set and ordering. Wording stays
per-repo-authored.

## Tiering — README only vs README + docs/

```
Tier 1  Single-package wrapper, no NixOS/HM module           → README only
Tier 2  Package + module (NixOS or HM), small option set      → README only
Tier 3  Multi-component (≥2 packages, or module ≥10 options,  → README + docs/
        or multiple subsystems like vfio-stealth)
```

Tier promotion criteria (any one triggers Tier 3):

- More than one tracked source tree under the repo (`acpi/`, `kernel/`,
  `qemu/`, etc.)
- NixOS/HM module with ≥10 user-facing options
- Domain knowledge prerequisite to use safely (security boundaries,
  hardware risk, kernel patches)
- Configuration reference exceeds ~80 lines if inlined into README

Examples by tier:

- Tier 1: `durdraw-nix`, `ripgrep-nix`, `models-nix`, `lsfg-vk-nix`,
  `nx-save-sync-nix`, `OCCT-nix`, `openviking-nix`, `gemini-cli-nix`,
  `lmstudio-nix`, `rocksmith-nix`, `cachyos-settings-nix`,
  `streamcontroller-nix`, `goxlr-hm-nix`, `eden-nix`, `mesa-git-nix`
- Tier 2: `coolercontrol-nix`, `yeetmouse-nix`, `mullvad-vpn-nix`
- Tier 3: `portmaster-nix`, `vfio-stealth-nix`

## Required README.md sections (all tiers)

Order is fixed. Wording per-repo. Sections marked OPT may be omitted
when not applicable.

```
# <repo-name>

<badge block>                              [REQ]  CI, License, NixOS, last
                                                  commit, Stars, Issues
                                                  (canonical 6 — see below)

<one-line description with upstream link>  [REQ]  one sentence, links
                                                  upstream project + author

## Upstream                                [REQ]  attribution block

## What Is This?                           [REQ]  why this repo exists
                                                  (separate from upstream)

## Components / What's Included            [OPT]  Tier 2/3 — table of
                                                  packages/modules shipped

## Requirements                            [OPT]  hardware / external deps
                                                  (Steam, GPU, kernel
                                                  module, etc.)

## Installation                            [REQ]  flake input + overlay +
                                                  module enable, in that
                                                  order

## Configuration                           [OPT]  Tier 2/3 — link to
                                                  options reference or
                                                  inline if short

## Development                             [REQ]  devShell, formatter,
                                                  pre-commit, how to run
                                                  update.sh, where CI lives

## Updates                                 [OPT]  upstream tracking
                                                  cadence, where bumps
                                                  land

## License                                 [REQ]  this repo's LICENSE +
                                                  upstream's license
                                                  (different files,
                                                  cite both)
```

### Canonical badge block

Six badges, in this order. Drop none, add none (extra package badges
like Python version may follow but stay below the canonical block):

```markdown
[![CI](https://github.com/Daaboulex/<repo>/actions/workflows/ci.yml/badge.svg)](https://github.com/Daaboulex/<repo>/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/Daaboulex/<repo>)](./LICENSE)
[![NixOS](https://img.shields.io/badge/NixOS-unstable-78C0E8?logo=nixos&logoColor=white)](https://nixos.org)
[![Last commit](https://img.shields.io/github/last-commit/Daaboulex/<repo>)](https://github.com/Daaboulex/<repo>/commits)
[![Stars](https://img.shields.io/github/stars/Daaboulex/<repo>?style=flat)](https://github.com/Daaboulex/<repo>/stargazers)
[![Issues](https://img.shields.io/github/issues/Daaboulex/<repo>)](https://github.com/Daaboulex/<repo>/issues)
```

### Upstream block — fixed shape

```markdown
## Upstream

This is a **Nix packaging wrapper** — not the original project. All
credit for `<upstream-name>` goes to:

- **Author**: [<name>](url)
- **Repository**: [<owner>/<repo>](url)
- **License**: [<SPDX>](link to upstream LICENSE)
```

For forks (e.g., `cachyos-settings-nix`) replace "packaging wrapper"
with "Nix-friendly fork" and add the divergence summary.

### Installation — fixed three-step shape

````markdown
## Installation

### 1. Add flake input

```nix
inputs.<short> = {
  url = "github:Daaboulex/<repo>";
  inputs.nixpkgs.follows = "nixpkgs";
};
```
````

### 2. Stack the overlay

```nix
nixpkgs.overlays = [ inputs.<short>.overlays.default ];
```

### 3. Import the module / install the package

(varies — package only / NixOS module / HM module — pick the relevant
sub-section, omit the others)

```

## Tier 3 docs/ folder — required files

Tier 3 repos add a `docs/` folder. The minimum file set:

```

docs/
├── ARCHITECTURE.md # directory layout, component boundaries,
│ # which file owns which option group
├── BUILD.md # operator commands beyond the README
│ # quick-install: dev shell, formatters, hooks,
│ # tests, update contract, troubleshooting
└── OPTIONS.md # full option reference (auto-generated where # possible — inherit nix repo's # `update-docs` pattern)

```

Optional files when they have meaningful content for the repo:
- `docs/STYLE.md` — language-specific coding rules. Skip if repo
  follows root `nix/docs/STYLE.md` unchanged (most repos).
- `docs/SECURITY.md` — domain-specific threat model (different from
  the repo-root `SECURITY.md` GHSA reporting policy). Used by
  vfio-stealth, portmaster, mullvad-vpn.
- `docs/<topic>.md` — anything domain-specific (e.g.,
  `docs/upstream-issue-draft.md` in portmaster-nix tracking the
  nixpkgs PR).

## What stays out of every README

- AI/agent scaffold (already enforced by REPO-STANDARD §Forbidden paths)
- Co-Authored-By footers, Claude/Gemini signatures
- Long changelogs (use git log + GitHub Releases)
- Roadmap items unrelated to the package
- Personal hardware notes (host-specific tuning lives in the main nix
  flake's `parts/hosts/<host>/`, never in the package repo)

## Adoption checklist (per repo)

```

[ ] Six canonical badges in canonical order
[ ] One-line intro with upstream link
[ ] ## Upstream block in fixed shape
[ ] ## What Is This? present
[ ] Components / Requirements where Tier ≥ 2
[ ] ## Installation in three-step shape
[ ] ## Development present (devShell, fmt, hook commands)
[ ] ## License cites BOTH this repo's LICENSE and upstream's
[ ] Tier 3: docs/ARCHITECTURE.md + docs/BUILD.md + docs/OPTIONS.md
[ ] No forbidden paths tracked (REPO-STANDARD §Forbidden paths)

```

## Related

- `docs/REPO-STANDARD.md` — file/CI/flake contract (v1.2)
- `docs/STYLE.md` — Nix coding rules (shared)
- `docs/ARCHITECTURE.md` — main flake's own architecture (sample
  Tier 3 doc set)

## Versioning

This template is versioned. Bump on:
- New required section
- Change to badge set or order
- Tier criteria change

History:
- 1.0 (2026-04-24) — initial draft after surveying 20 satellite repos
```

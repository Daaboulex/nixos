# Development

How formatting, hooks, checks, tests, and documentation work in this repository.

**See also** — the three project-standard docs have distinct scopes:

| Doc                                    | Owns                                                                |
| -------------------------------------- | ------------------------------------------------------------------- |
| **DEVELOPMENT.md** (this)              | operator commands, formatters, hooks, checks, tests, doc auto-regen |
| **[STYLE.md](STYLE.md)**               | code style rules + option conventions + §13a placement              |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | directory layout + parts-vs-home boundary + scope categories        |

All build infrastructure lives in `parts/_build/`:

| File            | Purpose                                                   |
| --------------- | --------------------------------------------------------- |
| `treefmt.nix`   | Formatter configuration (what formats what)               |
| `git-hooks.nix` | Pre-commit hooks + devShell                               |
| `tests.nix`     | NixOS VM integration tests                                |
| `overlays.nix`  | Composes per-input overlays into `flake.overlays.default` |

---

## Operator Commands

Primary build interface — shell wrapper around `nixos-rebuild` + `nvd` + specialisation awareness. Defined in `home/modules/zsh/default.nix`.

### `nrb` — build + switch

```bash
nrb                    # Build + switch current host (activates immediately)
nrb --update           # Update flake inputs + build + switch
nrb --update-no-kernel # Update all inputs except the cachyos-kernel pin
nrb --dry              # Build + show diff, don't activate
nrb --boot             # Build + activate on next reboot (not now)
nrb --trace            # Build with --show-trace (debugging)
nrb --check            # Evaluate ALL configs without building (fast sanity check)
nrb --host <name>      # Build a specific nixosConfiguration
nrb --list             # Show all configurations + specialisations
nrb --update --dry     # Update inputs + build + diff only
```

`nrb` detects the current host via `hostname` and builds only that one. Each host currently runs a single kernel variant; if a host adds specialisations later, every variant builds in a single `nrb` and appears as a separate systemd-boot entry.

Behaviour: build timing, kernel change detection, specialisation listing, `nvd` system diff, Home Manager generation diff, generation display, rollback hint. On a successful non-`--boot`, non-`--dry` switch, regenerates `docs/OPTIONS.md` in the background via `nix eval --raw --impure --file scripts/generate-docs.nix markdown` (the same path the `update-docs` hook uses). The full mdBook docs site lives behind `nix build .#docs` — `nrb` doesn't touch it.

### `nrb-check` — evaluate all configs

```bash
nrb-check              # Evaluate ALL configs + specialisations, no build
```

Standalone evaluator that auto-discovers every `flake.nixosConfigurations.*` and checks `.config.system.build.toplevel.drvPath`. Useful before committing changes that touch multiple hosts.

### `nrb-info` — system state

```bash
nrb-info               # Current generation, active specialisation, store size
```

Prints boot generation, live kernel + specialisation, `nix path-info /run/current-system`, and `nix-store --gc --print-roots` summary.

---

## Formatters

Configured in `parts/_build/treefmt.nix` via [treefmt-nix](https://github.com/numtide/treefmt-nix). Run manually with `nix fmt`.

| Formatter      | Files                               | What it does                                      |
| -------------- | ----------------------------------- | ------------------------------------------------- |
| **nixfmt**     | `*.nix`                             | Canonical Nix formatting                          |
| **deadnix**    | `*.nix`                             | Removes unused code (`--no-lambda-pattern-names`) |
| **statix**     | `*.nix`                             | Lints for anti-patterns                           |
| **shfmt**      | `*.sh`                              | Shell script formatting                           |
| **shellcheck** | `*.sh`                              | Shell script linting                              |
| **prettier**   | `*.json`, `*.yaml`, `*.yml`, `*.md` | JSON/YAML/Markdown formatting                     |

**Excludes:** `docs/*.example` (auto-generated), `flake.lock`, `repos/**`.

---

## Git Hooks

Configured in `parts/_build/git-hooks.nix` via [git-hooks.nix](https://github.com/cachix/git-hooks.nix). Hooks are **auto-installed** into `.git/hooks/` when you run `nix develop`.

All 14 hooks run on every `git commit`. Grouped by concern:

### Formatting + eval

| Hook             | Trigger            | What it enforces                                                                        |
| ---------------- | ------------------ | --------------------------------------------------------------------------------------- |
| `auto-format`    | any staged file    | Runs `treefmt` on staged files + re-stages formatted versions. Rejects on syntax error. |
| `nix-eval-check` | any staged `*.nix` | Evaluates `system.build.toplevel.drvPath` for every `flake.nixosConfigurations.*`.      |

### Style / §13a enforcement

| Hook                     | Trigger                              | What it enforces                                                                                         |
| ------------------------ | ------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| `check-module-docstring` | any `parts/` or `home/modules/` file | STYLE §1.1 — every non-helper module starts with `# <name> — <one-line purpose>.`                        |
| `check-no-with-lib`      | any `*.nix`                          | STYLE §1.3 — `with lib;` is forbidden anywhere.                                                          |
| `check-mkforce-comment`  | any `*.nix` outside `hosts/`         | STYLE §4.2 — every `lib.mkForce` has a `# Why:` comment in the adjacent comment block.                   |
| `check-assertion-format` | any `*.nix`                          | STYLE §3.2 — `{ assertion = …; message = …; }` messages start with `"myModules.<path>:"`.                |
| `check-placement`        | any `parts/` or `home/modules/` file | STYLE §13a — directory path mirrors option scope (`parts/<scope>/*.nix` declares `myModules.<scope>.*`). |

### Host / repo-state

| Hook                       | Trigger           | What it enforces                                                                                                                                         |
| -------------------------- | ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `hm-exhaustiveness`        | any `home/` file  | Every `home/modules/<name>/` has a `myModules.home.<name>.enable` entry in BOTH host configs.                                                            |
| `nixos-exhaustiveness`     | any `parts/` file | Every `parts/<category>/<name>.nix` module is imported into every host that shouldn't opt out (explicit exclude-list in each host's `flake-module.nix`). |
| `check-no-roadmap-in-docs` | any `docs/` file  | ROADMAP-style planning artifacts stay in `.ai-context/.superpowers/`, not in `docs/` or repo root.                                                       |
| `check-behind-remote`      | pre-commit        | Refuses commits when local is behind `origin/main`. Prevents divergent-histories foot-gun when multiple hosts commit without pulling first.              |

### Repo integrity

| Hook                 | Trigger         | What it enforces                                                                                                                                           |
| -------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `check-secrets-leak` | any staged file | Blocks staging files in `secrets/` (except `secrets.nix`), `.age`, `.key`, `.pem`, private keys, and `SECURITY-AUDIT-2026-05-04.md`.                       |
| `check-scrub-tokens` | any staged file | Scans staged content for forbidden tokens (hostnames, project names, internal paths) that must not appear in the public repo. Config: `scrub-config.json`. |
| `check-no-ai-files`  | any staged file | Blocks committing AI context files (AGENTS.md, CLAUDE.md, GEMINI.md, .claude/, .gemini/, .codex/). These are symlinks into `.ai-context/` submodule.       |

All custom hooks are `pkgs.writeShellApplication` (not `writeShellScript`) so they get shellcheck at build and `set -euo pipefail` automatically. To bypass for a specific transient issue:

```bash
SKIP=nix-eval-check git commit ...   # skip one hook
```

Do NOT bypass with `--no-verify` — that skips ALL hooks and hides real violations.

---

## Flake Checks

Run with `nix flake check`. Full check set (46 checks):

```bash
# Fast eval-only (~10s):
nrb --check

# Structural check — no VM tests (~30s):
nix flake check --no-build

# All fast checks — eval canaries + runCommand (~30s):
nix build --no-link '.#checks.x86_64-linux.eval-'{kernel-cachyos,boot-lanzaboote,security-hardening,services-earlyoom,hardware-networking,nix-flakes,users-zsh,hardware-graphics-mesa-git,portmaster-dns-interception,vfio-iommu-params,scx-scheduler,mullvad-lockdown,networking-dot,nix-trusted-users,kernel-modules-vfio,x3d-vcache-mode,mbp-kernel-cachyos-lto}

# Single check:
nix build --no-link '.#checks.x86_64-linux.<name>'

# Full suite including VMs (~10-20min cached, ~60min cold):
nix flake check
```

**Which command to use:**

| Situation                         | Command                                                     |
| --------------------------------- | ----------------------------------------------------------- |
| Daily development (fast feedback) | `nrb --check` or `nix flake check --no-build`               |
| Pre-commit sanity                 | pre-commit hooks handle this automatically                  |
| MacBook / slow machines           | `nix flake check --no-build` (never bare `nix flake check`) |
| CI / full validation              | `nix flake check` (includes all VM tests)                   |
| Single VM test                    | `nix build --no-link '.#checks.x86_64-linux.vm-core'`       |

VM tests boot QEMU VMs with KVM acceleration. Each takes 3-7 min.
On machines without KVM or with limited RAM, use `--no-build`.

### Check Categories

| Prefix       | Type                                                | Speed    | Count |
| ------------ | --------------------------------------------------- | -------- | ----- |
| `eval-*`     | Config property canary — probes host config values  | <1s each | 23    |
| `nrb-*`      | nrb flag validation + regex tests                   | <1s each | 7     |
| `check-*`    | Pre-commit hook self-tests (fixture-based)          | <30s     | 2     |
| `vm-*`       | VM integration — boots QEMU, tests service behavior | 1-5min   | 10    |
| `smoke-*`    | Per-tier host smoke — partial host config in VM     | 2-5min   | 2     |
| `toplevel-*` | Full system closure build                           | 1-10min  | 2     |

### Eval Canaries (instant, catch silent regressions)

| Check                              | What it catches                                                |
| ---------------------------------- | -------------------------------------------------------------- |
| `eval-kernel-cachyos`              | CachyOS kernel overlay fell back to stock nixpkgs              |
| `eval-hardware-graphics-mesa-git`  | mesa-git overlay not applied                                   |
| `eval-boot-lanzaboote`             | Secure boot disabled, systemd-boot conflict, pkiBundle wrong   |
| `eval-security-hardening`          | Hardening module disabled, polkit/rtkit off                    |
| `eval-services-earlyoom`           | OOM killer disabled                                            |
| `eval-portmaster-dns-interception` | Mullvad bootstrap deadlock (DNS interception not forced off)   |
| `eval-vfio-iommu-params`           | GPU passthrough broken (amd_iommu/iommu=pt missing)            |
| `eval-scx-scheduler`               | Wrong sched_ext scheduler (scx_lavd has crash bugs)            |
| `eval-mullvad-lockdown`            | VPN kill-switch disabled (IP exposure at boot)                 |
| `eval-networking-dot`              | DNS-over-TLS dropped to plaintext                              |
| `eval-nix-flakes`                  | Flakes/nix-command not in experimental-features                |
| `eval-nix-trusted-users`           | Primary user not in nix trusted-users                          |
| `eval-hardware-networking`         | NetworkManager disabled                                        |
| `eval-users-zsh`                   | Primary user shell not zsh                                     |
| `eval-kernel-modules-vfio`         | VFIO kernel modules missing                                    |
| `eval-x3d-vcache-mode`             | X3D V-Cache not in cache mode                                  |
| `eval-mbp-kernel-cachyos-lto`      | MBP kernel drift (variant, BORE scheduler, no specialisations) |

### nrb Tests (flag validation + timing)

| Check                                     | What it catches                                 |
| ----------------------------------------- | ----------------------------------------------- |
| `nrb-flag-compat-boot-deploy`             | `--deploy --boot` silently accepted             |
| `nrb-flag-compat-update-deploy`           | `--deploy --update` silently accepted           |
| `nrb-flag-compat-update-no-kernel-deploy` | `--deploy --update-no-kernel` silently accepted |
| `nrb-flag-compat-host-deploy`             | `--host --deploy` mutual exclusion              |
| `nrb-flag-unknown`                        | Unknown flags silently accepted                 |
| `nrb-help-output`                         | `--help` broken or exits nonzero                |
| `nrb-activate-regex-test`                 | Store path validation regex in nrb-activate     |
| `vm-nrb-build-fail-timing`                | Build failure hangs 60s (sudo keepalive bug)    |
| `vm-nrb-preflight-no-daemon`              | Daemon-down not detected cleanly                |

### VM Integration Tests

| Check                  | What it proves                                                   |
| ---------------------- | ---------------------------------------------------------------- |
| `vm-core`              | Nix daemon + flakes + cgroups + user creation + groups + zsh     |
| `vm-ssh`               | SSH hardening, fail2ban, firewall port                           |
| `vm-networking`        | NetworkManager + systemd-resolved + DNS-over-TLS (opportunistic) |
| `vm-hardware-pipewire` | PipeWire starts, LADSPA config wired                             |
| `vm-security-agenix`   | agenix + age CLI tools available                                 |
| `vm-boot-impermanence` | Bind mount from /persist verified via findmnt                    |
| `smoke-v2`             | v2-tier (MBP): NM + Syncthing active                             |
| `smoke-v4`             | v4-tier (Ryzen): NM + Syncthing active                           |

---

## DevShell

```bash
nix develop
```

Enters a shell with all formatters and pre-commit hooks installed. The first `nix develop` in a fresh clone installs hooks into `.git/hooks/pre-commit`. The `.pre-commit-config.yaml` is auto-generated — do not edit it.

Auto-loaded by direnv when you `cd` into the repo (via `.envrc`).

---

## Documentation Generation

Documentation is generated as build artifacts via `nix build .#docs`. The `scripts/generate-all-docs.nix` expression produces option reference, module catalog, and host templates from live option definitions in a single eval.

```bash
nix build .#docs         # Build mdBook documentation site
nix run .#docs-serve     # Local preview server
```

Generated files (OPTIONS.md, options.json, templates) are gitignored — they are always derivable from the code.

---

## Overlays

`parts/_build/overlays.nix` composes the per-input `overlays.default`
attrs into a single `flake.overlays.default` consumed by every host.
Each external flake input that provides an overlay (vfio-stealth,
linux-corecycler, mesa-git-nix, claude-code, etc.) is
listed here in load order; `compose` is a left-fold of `final → prev →
overlay-output` so later entries can override earlier ones.

The file contains no relay overlays — it doesn't define new
derivations. Custom packages live in their respective `repos/*-nix`
flakes (or external inputs); this file is purely the composition.

---

## The Commit Flow

```text
Edit files
    │
    ▼
git add
    │
    ▼
git commit
    │
    ├─ auto-format             Formats staged files, re-stages them
    ├─ check-assertion-format  Style: assertion message prefix
    ├─ check-behind-remote     Refuse commits when behind origin
    ├─ check-mkforce-comment   Style: mkForce # Why: discipline
    ├─ check-module-docstring  Style: docstring header
    ├─ check-no-roadmap-in-docs Planning artifacts in .ai-context/ only
    ├─ check-no-with-lib       Style: no `with lib;`
    ├─ check-placement         STYLE §13a path/scope mirror
    ├─ check-secrets-leak      Repo integrity: no secrets staged
    ├─ check-scrub-tokens      Repo integrity: no forbidden tokens
    ├─ hm-exhaustiveness       HM modules wired in every host
    ├─ nix-eval-check          Every nixosConfigurations.* evals
    ├─ nixos-exhaustiveness    parts/ modules imported in every host (or excluded)
    (docs are build artifacts via `nix build .#docs`, not committed)
    │
    ▼
Commit succeeds (or is rejected with clear error)
    │
    ▼
nix flake check                Re-validates everything + runs VM tests
```

No manual `nix fmt` needed. No stale docs. No missing module toggles. No broken configs.

---

## Manual Test Checklists

Modules requiring real hardware, network, or desktop sessions that cannot be reproduced in a VM.

### Portmaster + Mullvad Stack

Run after any change to `parts/security/portmaster*.nix`, `parts/services/mullvad.nix`, or `parts/hardware/networking.nix`:

1. `mullvad status` → Connected
2. `sudo iptables -t mangle -S PORTMASTER-INGEST-OUTPUT | head -1` → contains `0x6d6f6c65`
3. Browse any site → works
4. `resolvectl status | grep DNSOverTLS` → shows `opportunistic`
5. `mullvad disconnect` → browse any site → still works (Quad9 fallback)
6. `mullvad connect` → browse → works within 5s

### PipeWire + DeepFilterNet Denoise

Run after any change to `parts/hardware/pipewire.nix` or `home/modules/goxlr/denoise.nix`:

1. `systemctl --user status pipewire` → active
2. `wpctl status` → shows filter-chain nodes (DeepFilter)
3. GoXLR mic input → speak → verify noise reduction active
4. No crackling/artifacts at idle

### Kernel (CachyOS + LTO)

Run after `nix flake update cachyos-kernel`:

1. `uname -r` → contains `cachyos` or `lto`
2. `dmesg | grep -i "kernel\|bore\|bpf"` → no errors
3. `cat /proc/version` → matches expected

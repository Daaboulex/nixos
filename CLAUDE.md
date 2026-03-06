# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Modular NixOS flake configuration for a Ryzen 9950X3D desktop system. Built on **flake-parts** with a custom `myModules.*` option namespace for toggling features declaratively.

### Design Philosophy

This project follows a **dendritic architecture** — every concern branches into its own self-contained module with explicit option interfaces, composed at the host level like a tree. The goals are:

- **True modularity**: every feature is an independent, toggleable module behind `myModules.*`. No monolithic configuration files. Modules must be usable in isolation and composable in any combination.
- **Bleeding-edge packages**: tracks `nixos-unstable`, CachyOS kernels with LTO, and latest upstream flake inputs. Prefer the newest viable version of everything.
- **Maximum performance**: CachyOS kernel with microarchitecture-specific compilation (Zen 5 / x86-64-v4), bore scheduler, IO scheduler tuning, ananicy-cpp process prioritization, sysctl optimizations, THP, and hardware-specific governor/driver settings.
- **Best practices**: flake-parts for structured composition, sops-nix for secrets, Lanzaboote for Secure Boot, hardened SSH with fail2ban, proper NixOS module option patterns (`mkEnableOption`/`mkIf`), overlays for external packages.

When adding or modifying anything in this repo, always aim for the most performant, most modular, and most correct approach. Prefer upstream NixOS options over raw config when available. Use `lib.mkDefault`, `lib.mkForce`, and option priorities correctly. Keep modules single-responsibility — if a module grows to cover two concerns, split it.

## Common Commands

### `nrb` — NixOS Rebuild Helper

The primary build command, defined in `home/modules/zsh/default.nix`:

```bash
nrb                    # Build + switch
nrb --update           # Update flake inputs + build + switch
nrb --dry              # Build + show diff, don't activate
nrb --boot             # Build + activate on next reboot
nrb --trace            # Build with --show-trace (debugging)
nrb --update --dry     # Update inputs + build + diff only
```

Features: build timing, kernel change detection (warns if reboot needed), nvd system diff, Home Manager generation diff, generation number display, rollback hint. Build runs unprivileged (only profile set + activation use sudo).

### Other Commands

```bash
# Update a specific flake input
nix flake update <input-name>

# Generate option documentation
bash scripts/update-docs.sh

# Validate all configs, shell functions, and docs (no switch, read-only)
bash scripts/test-shell-functions.sh
```

### Shell Aliases

| Alias | Command |
|---|---|
| `gc` | `sudo nix-collect-garbage -d && nix-collect-garbage -d && sudo nix-store --optimize` |
| `lc` | Clear system logs (dmesg, journald, /var/log) |
| `cat` | `bat --paging=never` (syntax-highlighted) |
| `z <dir>` | zoxide smart cd (learns frequent dirs) |

### Shell Tool Integrations

Configured in `home/modules/zsh/default.nix`:
- **zoxide** — smart `cd` replacement (`z` command, learns directories)
- **fzf** — fuzzy finder (Ctrl+R history, Ctrl+T files, Alt+C dirs)
- **direnv** + **nix-direnv** — auto-loads `.envrc` / `shell.nix` per directory
- **bat** — syntax-highlighted `cat` replacement
- **starship** — modern shell prompt

## Architecture

### Flake Structure (flake-parts)

`flake.nix` uses **flake-parts** (`hercules-ci/flake-parts`) to compose the system — not raw flake outputs. This gives structured `perSystem` scoping and modular imports. The top-level flake delegates to `parts/flake-module.nix` which imports all module definitions and host configurations. New modules, hosts, and overlays are added by extending the imports in `parts/flake-module.nix`, never by editing `flake.nix` outputs directly.

### Module System

All custom modules live under `parts/` and are exported as `nixosModules.<scope>-<name>`:

- `parts/system/` — boot, kernel, nix daemon, users, security, filesystems, packages, services, ssh, sops, cachyos-settings
- `parts/hardware/` — cpu (amd/intel), gpu (amd/intel/nvidia), graphics, audio, networking, bluetooth, performance, power, macbook, yeetmouse, goxlr, piper, streamcontroller
- `parts/desktop/` — kde, displays, flatpak
- `parts/apps/` — gaming, tools, arkenfox, portmaster, tidalcycles, wine

Each module follows this pattern:
```nix
{ config, lib, pkgs, ... }:
let cfg = config.myModules.<scope>.<feature>;
in {
  options.myModules.<scope>.<feature> = {
    enable = lib.mkEnableOption "...";
    # feature-specific options
  };
  config = lib.mkIf cfg.enable { ... };
}
```

### Host Configuration

Hosts live in `parts/hosts/<hostname>/`:
- `flake-module.nix` — defines `nixosConfigurations.<hostname>`, imports all needed nixosModules and external modules, stacks overlays
- `default.nix` — host-specific settings, enables/configures `myModules.*` options
- `hardware-configuration.nix` — auto-generated hardware probe (do not edit manually)

Current hosts: `ryzen-9950x3d` (desktop) and `macbook-pro-9-2` (laptop). The MacBook uses **specialisations** for kernel variants (xanmod, cachyos) — these create additional boot entries within a single build. All overlays (including CachyOS kernel) are included in the base overlay list so specialisations can switch kernel variants without needing different pkgs fixpoints.

### Home Manager

User-level configuration lives in `home/`:
- `home.nix` — entry point, auto-discovers hostname/username from system config
- `home/modules/` — modular configs (git, zsh, plasma, vscode, flatpak, etc.) auto-discovered via `default.nix`. The zsh module also configures zoxide, fzf, direnv, bat, and starship.
- `home/hosts/<hostname>/` — host-specific Home Manager settings (e.g., flatpak app lists)

Home Manager is integrated as a NixOS module (not standalone).

### Overlays

Eight external overlays are stacked in the host's `flake-module.nix` (cachyos-kernel, tidalcycles, antigravity, nx-save-sync, portmaster, occt-nix, claude-code, plus `self.overlays.default`). Custom overlays go in `parts/overlays.nix`.

### Secrets

Secrets are managed with **sops-nix**. Encrypted secrets live in `secrets/secrets.yaml`. Age key at `/var/lib/sops-nix/key.txt`. Configured via `parts/system/sops.nix`.

## Key Conventions

- **Dendritic modularity**: every feature gets its own module file with `myModules.*` options. Never add NixOS config without gating it behind a `myModules` enable flag. If a module touches two unrelated concerns, split it into two modules.
- **Module pattern**: always use `lib.mkEnableOption` + `lib.mkIf cfg.enable`. Expose sub-options for anything the host config might want to tune. Use `lib.mkDefault` for sensible defaults that hosts can override. In host configs, any option that a **specialisation overrides** must also use `lib.mkDefault` so the specialisation can win the merge (specialisations set values at normal priority).
- **Flake-parts composition**: add new modules in `parts/flake-module.nix` imports. Export as `nixosModules.<scope>-<name>`. Import in the host's `flake-module.nix`.
- **Bleeding edge**: track `nixos-unstable`. Prefer latest upstream versions. The CachyOS kernel input must NOT have its nixpkgs overridden (patch/version mismatch risk — see comment in `flake.nix`).
- **Performance-first**: when multiple approaches exist, choose the one with better runtime performance. Use hardware-specific options (microarch, governors, schedulers) over generic defaults.
- **Overlays for external packages**: third-party packages enter via overlays stacked in the host's `flake-module.nix`. Custom overlays go in `parts/overlays.nix`.
- `allowUnfree = true` is set globally
- System targets `x86_64-linux` only
- **Documentation maintenance**: every code change must update ALL affected documentation. Specifically:
  - **`docs/OPTIONS.md`**: regenerate via `bash scripts/update-docs.sh` when adding/modifying module options or new modules. Every option must have a `description` string.
  - **`README.md`**: update module reference tables when module structure changes (new modules, renamed modules, new categories). Update option counts, overlay tables, and feature descriptions when capabilities change.
  - **`docs/installation.md`**: update when changing the install script, partition layout, post-install steps, or host configurations.
  - **`docs/secure-boot.md`**: update when changing Lanzaboote, sbctl, or Secure Boot configuration.
  - **`CLAUDE.md`**: update when changing build commands, architecture patterns, key conventions, or adding new tooling/workflows.
  - **`scripts/install-btrfs.sh`**: update post-install hints and safety messages when changing user management, passwd defaults, or filesystem options.
  - **`scripts/test-shell-functions.sh`**: run after changes to zsh functions, nrb flags, or documentation to validate — the test script auto-extracts flags and functions from the zsh source so it stays in sync automatically.
  - **General rule**: if you change behavior, update every doc that references that behavior. When in doubt, grep the `docs/`, `scripts/`, `README.md`, and `CLAUDE.md` for related keywords.
- **No hardcoded values in generic modules**: usernames, paths, hardware IDs, and host-specific settings must be options with `lib.mkDefault` or set in host configs. Gate vendor-specific config behind `(config.myModules.hardware.*.enable or false)`.

## Dual-Model Protocol: Claude + Gemini CLI

Claude is the primary architect and pair programmer. The **Gemini CLI** (`gemini`) serves as a high-capacity analytical engine (1M token context window) for large-scale codebase operations.

### When to Delegate to Gemini CLI

Claude must delegate primary analysis to `gemini` when:

- **Large files**: any single file exceeds ~300 lines (check with `wc -l`)
- **High context volume**: total target files for a request exceed ~100KB
- **Bulk refactors**: task affects 5+ files simultaneously
- **Initial mapping**: first exploration of a directory structure >50k lines

### Gemini CLI Reference

**Invocation modes:**
```bash
# Interactive session (REPL) — use @ inside prompts for file injection
gemini

# Headless / non-interactive — use -p flag
gemini -p "Explain the boot module" @parts/system/boot.nix

# Pipe input
cat parts/system/kernel.nix | gemini -p "Review this kernel config"
```

**File/directory ingestion with `@` (recursive, respects .gitignore):**
```bash
# In any prompt (interactive or -p), prefix paths with @
gemini -p "Summarize the architecture" @parts/
gemini -p "Review these changes" @parts/system/ @parts/hardware/
```

**Model selection with `-m`:**
```bash
gemini -m gemini-3-pro-preview -p "Deep audit" @parts/       # Pro: deep reasoning
gemini -m gemini-3-flash-preview -p "Quick check" @home/      # Flash: fast/frequent
```

**Approval and sandbox modes:**
```bash
gemini --yolo -p "Format all nix files" @parts/               # Auto-approve all tool calls (sandboxed)
gemini --sandbox -p "Refactor modules" @parts/                 # Sandbox without auto-approve
gemini --checkpointing -p "Reorganize" @parts/                 # Snapshot before file edits (/restore to undo)
```

**Structured output for scripting:**
```bash
gemini -p "List all myModules options" @parts/ --output-format json
gemini -p "Audit modules" @parts/ --output-format stream-json  # Real-time streaming
```

**Key interactive slash commands:**
- `/compress` — summarize context to save tokens
- `/chat save <tag>` / `/chat resume <tag>` — checkpoint conversations
- `/restore` — undo file edits made by tools
- `/stats` — show token usage
- `/memory add <text>` — persist notes across sessions
- `!<cmd>` — run shell command; `!` alone toggles persistent shell mode

### Rate Limit Handling

Free tier: 60 requests/min, 1,000 requests/day.

| Error Type | Detection | Action |
|---|---|---|
| Burst limit | `PerMinute` or `retryDelay < 5m` | Wait specified time and retry silently |
| Daily limit | `RESOURCE_EXHAUSTED` or `PerDay` | Fallback: `gemini -m gemini-3-flash-preview` |
| Terminal | All tiers hit daily limit | Stop and report to user |

```bash
# Auto-fallback from Pro to Flash on failure
gemini -m gemini-3-pro-preview -p "Audit @parts/" || gemini -m gemini-3-flash-preview -p "Audit @parts/"
```

### Useful Delegation Patterns for This Repo

```bash
# Security review
gemini -p "Perform a security review" @parts/system/ssh.nix @parts/system/security.nix

# Consistency check: host config vs module option definitions
gemini -p "Verify all myModules.* options used in default.nix are defined" @parts/hosts/ryzen-9950x3d/default.nix @parts/

# Audit option coverage
gemini -p "List any myModules options that are defined but never enabled" @parts/

# Heavy output — redirect then have Claude read only the summary
gemini -p "Full audit of module structure" @parts/ > .gemini_audit_tmp.txt
```

### Configuration & Context Management

- **GEMINI.md**: Gemini CLI reads `GEMINI.md` from project root (and subdirectories hierarchically). Mirror key conventions from `CLAUDE.md` into `GEMINI.md` for consistency.
- **Settings**: project-level config in `.gemini/settings.json`, user-level in `~/.gemini/settings.json`
- **`.geminiignore`**: exclude files from context (like `.gitignore` syntax)
- Redirect heavy Gemini output to a temp file and have Claude read only the summary to preserve context
- After a major Gemini-assisted analysis, consider `/clear` in Claude to reclaim context

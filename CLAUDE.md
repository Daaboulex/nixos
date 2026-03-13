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

**If a user prompt is ambiguous or unclear, always ask for clarification before proceeding.** Do not guess intent — wrong assumptions waste more time than a quick question. This applies especially to: which host a change targets, whether to add or remove something, and scope of refactors.

## Common Commands

### `nrb` — NixOS Rebuild Helper

The primary build command, defined in `home/modules/zsh/default.nix`:

```bash
nrb                    # Build + switch
nrb --update           # Update flake inputs + build + switch
nrb --dry              # Build + show diff, don't activate
nrb --boot             # Build + activate on next reboot
nrb --trace            # Build with --show-trace (debugging)
nrb --check            # Evaluate all configs without building (fast sanity check)
nrb --host <name>      # Build a specific nixosConfiguration
nrb --list             # Show all configurations + specialisations
nrb --update --dry     # Update inputs + build + diff only
```

Related standalone functions:
- `nrb-check` — same as `nrb --check` (evaluate all configs + specialisations)
- `nrb-info` — show current system state, generations, active specialisation, store size, HM generation

Features: build timing, kernel change detection (warns if reboot needed), nvd system diff, Home Manager generation diff, specialisation listing, generation number display, rollback hint, background docs regeneration. Build runs unprivileged (only profile set + activation use sudo).

### Other Commands

```bash
# Update a specific flake input
nix flake update <input-name>

# Format all code
nix fmt

# Run all checks (formatting, linting, VM tests)
nix flake check

# Enter devShell with pre-commit hooks
nix develop

# Run a specific VM test
nix build .#checks.x86_64-linux.vm-ssh --print-build-logs

# Declarative disk partitioning (new installs)
sudo nix run github:nix-community/disko -- --mode disko parts/hosts/<hostname>/disko.nix

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

`flake.nix` uses **flake-parts** (`hercules-ci/flake-parts`) to compose the system — not raw flake outputs. This gives structured `perSystem` scoping and modular imports. The top-level flake delegates to `parts/flake-module.nix` which imports all module definitions and host configurations. Beyond NixOS modules and hosts, `parts/flake-module.nix` also imports `treefmt.nix` (code formatting), `git-hooks.nix` (pre-commit hooks), and `tests.nix` (VM integration tests). New modules, hosts, and overlays are added by extending the imports in `parts/flake-module.nix`, never by editing `flake.nix` outputs directly.

### Module System

Modules are organized into two kinds:

**Grouped modules** live in directories when they form a natural family with shared concern:
- `parts/system/` — boot, kernel, nix daemon, users, filesystems, packages, services, impermanence, cachyos-settings (`system-cachyos`)
- `parts/security/` — hardening, ssh, sops, arkenfox, portmaster
- `parts/hardware/` — kernel drivers & firmware ONLY: cpu (amd/intel), gpu (amd/intel/nvidia), graphics, audio, networking, bluetooth, sensors, performance, power
- `parts/desktop/` — kde, displays, flatpak
- `parts/input/` — piper, yeetmouse, ducky-one-x-mini, streamcontroller
- `parts/diagnostics/` — sysdiag, iommu, corecycler

**Standalone modules** are named after themselves — no artificial grouping:
- `parts/coolercontrol.nix`, `parts/goxlr.nix`, `parts/tidalcycles.nix`, `parts/gaming.nix`, `parts/development.nix`, `parts/debugging-probes.nix`
- `parts/macbook/` — directory because it contains multiple files (patches, device configs)

**Structural rule**: grouped modules use `nixosModules.<scope>-<name>` exports and `myModules.<scope>.<feature>` option paths. Standalone modules use `nixosModules.<name>` and `myModules.<name>`. When deciding where a new module goes: if it configures kernel/drivers/firmware for a general subsystem, it goes in `hardware/`. Input devices go in `input/`. Diagnostic/testing tools go in `diagnostics/`. Everything else is standalone.

Each module follows this pattern:
```nix
# Grouped module (e.g. parts/security/ssh.nix)
{ inputs, ... }: {
  flake.nixosModules.<scope>-<name> = { config, lib, pkgs, ... }:
    let cfg = config.myModules.<scope>.<feature>; in {
      _class = "nixos";
      options.myModules.<scope>.<feature> = { enable = lib.mkEnableOption "..."; };
      config = lib.mkIf cfg.enable { ... };
    };
}

# Standalone module (e.g. parts/coolercontrol.nix)
{ inputs, ... }: {
  flake.nixosModules.<name> = { config, lib, pkgs, ... }:
    let cfg = config.myModules.<name>; in {
      _class = "nixos";
      options.myModules.<name> = { enable = lib.mkEnableOption "..."; };
      config = lib.mkIf cfg.enable { ... };
    };
}
```

Note: some standalone modules use scoped export names when their options live under a grouped namespace (e.g., `nixosModules.development-debugging-probes` for `myModules.development.debuggingProbes`, `nixosModules.gaming-wine` for `myModules.gaming.wine`).

Option naming: use `lib.mkEnableOption "Foo"` (not `"Enable Foo"` — mkEnableOption adds "Enable" automatically). Sub-options can be bare booleans (`lib.mkEnableOption "..."`) or `lib.mkOption` with `default = true` for opt-out categories (see `packages.nix`).

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

External overlays are stacked in the host's `flake-module.nix`. The ryzen host has 13 overlays (cachyos-kernel, tidalcycles, antigravity, nx-save-sync, portmaster, occt-nix, claude-code, mesa-git, lsfg-vk, vkbasalt-overlay, coolercontrol, openviking, plus `self.overlays.default`). The macbook has a smaller subset. Custom overlays go in `parts/overlays.nix`.

### External Package Repos

The user's personal NixOS package repositories live at `repos/` (sibling to `parts/`, `home/`, etc.). These are **separate git repos** — not part of the main NixOS flake. They are the source for flake inputs like `portmaster`, `mesa-git-nix`, `lsfg-vk-nix`, etc.

- `repos/portmaster-nix` — Portmaster firewall (Go + Rust/Tauri + Angular)
- `repos/mesa-git-nix` — Bleeding-edge Mesa from git main
- `repos/cachyos-settings-nix` — CachyOS performance settings module
- `repos/lsfg-vk-nix` — Vulkan frame generation
- `repos/OCCT-nix` — OCCT hardware stress test
- `repos/coolercontrol-nix` — CoolerControl fan/cooling management (v4.0.1, overlay replaces nixpkgs 3.x)
- `repos/linux-corecycler` — Per-core CPU stability tester + PBO Curve Optimizer tuner (Qt6 GUI, no overlay — direct package input)
- `repos/openviking-nix` — OpenViking agent-native context database (Python + Rust + Go + C++, overlay + NixOS module)

When modifying these packages, edit the files in `repos/<name>/`, commit and push there, then `nix flake update <input-name>` in the main flake to pull the changes. Do **not** commit `repos/` contents into the main NixOS flake repo.

### Documentation Generation Pipeline

Three auto-generated doc files are produced by `scripts/update-docs.sh`:

1. **`docs/OPTIONS.md`** — full option reference with types, defaults, and descriptions. Generated by `scripts/generate-docs.nix` which introspects `eval.options.myModules` from the ryzen config.
2. **`docs/host-template.nix.example`** — NixOS host config template. Generated by `scripts/generate-host-template.nix`. Groups options by 2-level namespace (e.g., `hardware.cpu`, `gaming.gamemode`), shows types and defaults inline, skips complex defaults with reference to OPTIONS.md.
3. **`docs/hm-host-template.nix.example`** — Home Manager host config template. Generated by `scripts/generate-hm-template.nix`. Static template listing all HM module toggles and per-host settings sections.

Key details:
- Template files use `.example` extension (not `.nix`) so treefmt doesn't try to format them — they contain raw option defaults that aren't valid Nix syntax.
- `parts/treefmt.nix` has `settings.global.excludes = [ "docs/*.example" ]` for this reason.
- The generators use `builtins.getFlake (toString ./..)` to introspect the live option definitions at eval time.
- `nrb` runs `scripts/update-docs.sh` in the background after every successful switch.
- When adding/modifying module options, always run `bash scripts/update-docs.sh` to regenerate all three files.

### CoolerControl Integration

CoolerControl uses a **hybrid overlay + nixpkgs module** approach:
- **Overlay** (`inputs.coolercontrol.overlays.default`): replaces nixpkgs' CoolerControl 3.x packages with 4.0.1 from the external `coolercontrol-nix` repo.
- **nixpkgs module** (`programs.coolercontrol.enable`): the built-in NixOS module handles systemd service setup. Our dendritic wrapper at `parts/coolercontrol.nix` gates this behind `myModules.coolercontrol.enable`.
- **Daemon**: `coolercontrold` auto-starts at boot via `wantedBy = ["multi-user.target"]`.
- **GUI**: the nixpkgs module only adds the GUI to `systemPackages` — no autostart. The dendritic wrapper has an `autostart` option (default `true`) that creates `/etc/xdg/autostart/coolercontrol.desktop` at the NixOS level.
- The external `coolercontrol-nix` `module.nix` is NOT imported (conflicts with the nixpkgs built-in module at `options.programs.coolercontrol`). Only the overlay is used.

### Secrets

Secrets are managed with **sops-nix**. Encrypted secrets live in `secrets/secrets.yaml`. Age key at `/var/lib/sops-nix/key.txt`. Configured via `parts/security/sops.nix`.

## Kernel, Scheduler & Power Stack

### CachyOS Kernel (LTO)

The project uses the **CachyOS kernel** from `chaotic-cx/nyx` flake input. Key properties:
- **LTO (Link-Time Optimization)**: entire kernel compiled with Clang LTO for microarchitecture-specific codegen (Zen 5 / `x86-64-v4` for desktop, `x86-64-v2` for MacBook Ivy Bridge)
- **BORE scheduler**: default CPU scheduler (Burst-Oriented Response Enhancer) — low-latency, burst-aware, good for desktop/gaming
- **sched-ext support**: BPF-based scheduler overlay framework (allows `scx_lavd`, `scx_rusty`, etc.)
- **Variants**: `cachyos` (standard), `cachyos-lto` (with LTO, what we use), `cachyos-sched-ext` (sched-ext focused). Set via `myModules.system.kernel.variant`
- The CachyOS kernel input must NOT have its nixpkgs overridden — patch contexts are tied to specific kernel source versions

### Scheduler Stack (5 Layers, No Conflicts)

The system runs a multi-layer scheduling stack. Each layer operates at a different level:

1. **amd_3d_vcache** (firmware) — Routes threads to CCD0 (V-Cache, 96MB L3) vs CCD1 based on `X3D_MODE` hint. Automatic, no kernel config needed.
2. **amd_pstate** (CPPC driver) — Controls CPU frequency scaling via EPP (Energy Performance Preference). Mode: `active`. Governor: `powersave` (correct — firmware handles dynamic boost, CPU still reaches max clocks under load).
3. **BORE** (kernel scheduler) — CachyOS default. Handles runqueue decisions, burst detection, latency optimization. Always active as the base scheduler.
4. **scx_lavd** (BPF overlay) — sched-ext scheduler that overlays BORE with latency-aware virtual deadline scheduling. Has its own autopilot power mode. Optional layer.
5. **ananicy-cpp** (userspace) — CachyOS process prioritization rules. Sets nice/ionice/cgroup per process. **Potential conflict with scx_lavd** — CachyOS wiki warns ananicy can amplify priority gaps and trigger scx watchdog timeouts.

### Governor & Power Configuration

- **`powersave` governor is correct** for `amd_pstate active` mode on Zen 5. Despite the name, it allows full boost clocks — the firmware (CPPC) handles dynamic scaling based on EPP hints. `performance` governor wastes 20-40W at idle by pinning all cores to max frequency.
- **Governor is set in ONE place**: `parts/hardware/performance.nix` via `powerManagement.cpuFreqGovernor = lib.mkDefault cfg.governor`. The `power.nix` module does NOT set governor (removed to avoid priority conflicts where `mkIf` at normal priority silently overrode `mkDefault`).
- **CachyOS settings module** (`cachyos-settings-nix`) controls sysctls only: `vm.swappiness` (150 with ZRAM), dirty byte limits, `vfs_cache_pressure`, IO schedulers (mq-deadline/kyber), THP, BBR/CAKE networking. It does **not** set governor or CPU scheduler — no conflict with the stack above.

### GameMode Integration (9950X3D)

GameMode (`gamemoderun`) interacts with the scheduler/power stack when a game starts:
- **Governor**: switches `powersave` → `performance` (EPP hint change on amd_pstate active — modest, dynamic scaling still works)
- **X3D cache mode**: dynamically shifts game to V-Cache CCD (`cache` mode), other processes to high-clock CCD (`frequency` mode) — the single most impactful optimization for dual-CCD X3D
- **Core pinning**: pins game processes to V-Cache CCD cores (auto-detected)
- **GPU**: sets `power_dpm_force_performance_level = high` on AMDGPU (forces max clocks)
- **Renice/ioprio**: **DISABLED** — conflicts with ananicy-cpp which manages priorities globally. Both fighting over nice/ionice values causes unpredictable behavior.
- **Split lock**: disables split-lock mitigation (helps some games)
- **Does NOT touch**: IO schedulers, sysctls, THP, scx_lavd, BORE scheduler, CachyOS settings

### Remote Deployment

Building for the MacBook from the desktop over SSH. Common approaches:
- **`nixos-rebuild --target-host`**: simplest but fragile — requires root SSH or `trusted-users` + signing keys on remote, and `nixos-rebuild-ng` on unstable has regressions
- **Manual `nix build` + `nix copy` + remote activate**: most reliable. Build locally, copy closure via SSH, activate on remote
- **`deploy-rs`**: Rust tool with automatic rollback on failed activation

See `/deploy` skill for the configured workflow.

## Key Conventions

- **Dendritic modularity**: every feature gets its own module file with `myModules.*` options. Never add NixOS config without gating it behind a `myModules` enable flag. If a module touches two unrelated concerns, split it into two modules. **File paths must mirror option namespaces** — `myModules.security.ssh` lives in `parts/security/ssh.nix`, NOT `parts/system/ssh.nix` or `parts/apps/ssh.nix`. The `nixosModules` export name follows the same pattern: `security-ssh`.
- **Module pattern**: always use `lib.mkEnableOption` + `lib.mkIf cfg.enable`. Expose sub-options for anything the host config might want to tune. Use `lib.mkDefault` for sensible defaults that hosts can override. In host configs, any option that a **specialisation overrides** must also use `lib.mkDefault` so the specialisation can win the merge (specialisations set values at normal priority).
- **Flake-parts composition**: add new modules in `parts/flake-module.nix` imports. Export as `nixosModules.<scope>-<name>` for grouped modules or `nixosModules.<name>` for standalone. Import in the host's `flake-module.nix`.
- **Bleeding edge**: track `nixos-unstable`. Prefer latest upstream versions. The CachyOS kernel input must NOT have its nixpkgs overridden (patch/version mismatch risk — see comment in `flake.nix`).
- **Performance-first**: when multiple approaches exist, choose the one with better runtime performance. Use hardware-specific options (microarch, governors, schedulers) over generic defaults.
- **Overlays for external packages**: third-party packages enter via overlays stacked in the host's `flake-module.nix`. Custom overlays go in `parts/overlays.nix`.
- `allowUnfree = true` is set globally
- System targets `x86_64-linux` only
- **Documentation maintenance**: every code change must update ALL affected documentation. Specifically:
  - **`docs/OPTIONS.md`**, **`docs/host-template.nix`**, **`docs/hm-host-template.nix`**: regenerate via `bash scripts/update-docs.sh` when adding/modifying module options or new modules. Every option must have a `description` string. The script also regenerates host config templates showing all options with types and defaults.
  - **`README.md`**: update module reference tables when module structure changes (new modules, renamed modules, new categories). Update option counts, overlay tables, and feature descriptions when capabilities change.
  - **`docs/installation.md`**: update when changing the install script, partition layout, post-install steps, or host configurations.
  - **`docs/secure-boot.md`**: update when changing Lanzaboote, sbctl, or Secure Boot configuration.
  - **`CLAUDE.md`**: update when changing build commands, architecture patterns, key conventions, or adding new tooling/workflows.
  - **`scripts/install-btrfs.sh`**: update post-install hints and safety messages when changing user management, passwd defaults, or filesystem options.
  - **`scripts/test-shell-functions.sh`**: run after changes to zsh functions, nrb flags, or documentation to validate — the test script auto-extracts flags and functions from the zsh source so it stays in sync automatically.
  - **General rule**: if you change behavior, update every doc that references that behavior. When in doubt, grep the `docs/`, `scripts/`, `README.md`, and `CLAUDE.md` for related keywords.
- **Module class annotation**: every `nixosModule` includes `_class = "nixos"` as the first attribute, preventing accidental import into wrong evaluation contexts (Home Manager, etc.).
- **`types.lazyAttrsOf`**: use `lib.types.lazyAttrsOf` instead of `lib.types.attrsOf` for attrs-of-submodule options (defers evaluation, avoids infinite recursion).
- **`withSystem` for per-system access**: use `{ inputs, withSystem, ... }:` in flake-parts modules that need per-system input packages (see `parts/gaming.nix` for the pattern).
- **treefmt formatting**: **ALWAYS run `nix fmt` before staging `.nix` files** — the pre-commit hook uses `--fail-on-change` and will reject unformatted code, causing commit failure. Run `nix fmt` from the repo root after editing any `.nix` file. Formatters: nixfmt, deadnix, statix, shfmt, shellcheck. This applies to external repos too (e.g. `repos/vkbasalt-overlay-src`).
- **Disko disk layouts**: each host has a `disko.nix` alongside `hardware-configuration.nix`. For new installs, use disko instead of `scripts/install-btrfs.sh`.
- **Impermanence**: opt-in module at `parts/system/impermanence.nix`. Phase 1 = system-only (wipes `/`, keeps `/home`). Requires `@persist` + `@root-blank` subvolumes. See module header for setup steps. User must explicitly enable after creating subvolumes.
- **VM tests**: add integration tests for new modules in `parts/tests.nix` using `pkgs.nixosTest`. Tests run headless in VMs and verify services start correctly.
- **Claude Code slash commands**: 21 custom skills in `.claude/commands/`. When adding new workflows or capabilities, create a matching slash command. When modifying existing workflows, update the corresponding command file. Full list:
  - **Build & Deploy**: `/build`, `/deploy`, `/rollback`, `/diff`, `/info`, `/gc`
  - **Code Quality**: `/check`, `/fmt`, `/test`, `/audit`, `/security-audit`
  - **Module Management**: `/add-module`, `/search-option`, `/option-coverage`
  - **Documentation**: `/update-docs`, `/profile-readme`
  - **Infrastructure**: `/update-input`, `/repos`, `/compare-hosts`, `/new-host`, `/impermanence`
- **No hardcoded values in generic modules**: usernames, paths, hardware IDs, and host-specific settings must be options with `lib.mkDefault` or set in host configs. Gate vendor-specific config behind `(config.myModules.hardware.*.enable or false)`.
- **Current option paths** (canonical reference — update this when paths change):
  - **Grouped**: `myModules.system.{boot,kernel,nix,users,filesystems,packages,services,impermanence,cachyos}`, `myModules.security.{hardening,ssh,sops,arkenfox,portmaster}`, `myModules.hardware.{core,cpu.amd,cpu.intel,graphics,gpu.amd,gpu.intel,gpu.nvidia,audio,networking,bluetooth,sensors,performance,power}`, `myModules.desktop.{kde,displays,flatpak}`, `myModules.input.{piper,yeetmouse,duckyOneXMini,streamcontroller}`, `myModules.diagnostics.{sysdiag,iommu,corecycler}`, `myModules.primaryUser`
  - **Standalone**: `myModules.gaming.*`, `myModules.gaming.wine.*`, `myModules.gaming.wine.bottles.enable`, `myModules.development.{enable,claudeCode,openviking,saleae,debuggingProbes}`, `myModules.goxlr.*`, `myModules.coolercontrol.{enable,autostart}`, `myModules.macbook.*`, `myModules.tidalcycles.*`, `myModules.vfio.*`
  - GPU options are under `hardware.graphics.*` for the shared graphics module; vendor-specific GPU modules are under `hardware.gpu.*` (e.g., `gpu.amd`, `gpu.intel`, `gpu.nvidia`)

### AI Agent & Versioning Best Practices

- **Always verify builds**: after any module change, run `nix eval .#nixosConfigurations.<hostname>.config.myModules.<path>.enable` to validate before suggesting `nrb`.
- **Parallel research**: use the Agent tool with `subagent_type=Explore` for codebase searches and `subagent_type=general-purpose` with web access for ecosystem research. Launch independent agents in parallel.
- **Commit discipline**: never auto-commit. Present changes to the user with `git diff --stat`. Use descriptive commit messages focused on "why" not "what".
- **Slash commands first**: before starting a task manually, check if a matching `/command` exists in `.claude/commands/`. Use skills for standardized workflows.
- **Skills maintenance**: when adding a new workflow or changing an existing one, always create or update the corresponding `.claude/commands/*.md` file. Skills are the canonical reference for how tasks are performed. **Proactively create new skills** when you notice a repeatable workflow that doesn't have one — don't wait to be asked. Skills prevent knowledge loss across sessions better than memory alone.
- **Memory updates**: after discovering important patterns, debugging insights, or user preferences, update `/home/user/.claude/projects/-home-user-Documents-nix/memory/MEMORY.md`. Check existing entries before adding to avoid duplicates.
- **Documentation sync**: every code change must update all affected docs (CLAUDE.md, README.md, docs/OPTIONS.md via `scripts/update-docs.sh`). Run `/update-docs` after structural changes.
- **Safe exploration**: use `nix eval` and `nix flake check --no-build` for validation, not full builds. Reserve `nrb` for when the user explicitly wants to switch.
- **External repos**: packages in `repos/` are separate git repositories. Edit there, push, then `nix flake update <input>` in the main flake. Never commit `repos/` contents into the main repo.

### Home Manager & KDE Module Change Protocol

When modifying any file under `home/modules/` or `home/hosts/`, follow this checklist:

1. **Generic vs host-specific**: settings that differ per machine (panel height, launchers, display layout) go in `home/hosts/<hostname>/default.nix` using `lib.mkForce` or plain values. Generic modules use `lib.mkDefault`.
2. **Plasma panel rules**:
   - Panel config (height, floating, widgets) is set declaratively via `programs.plasma.panels` — plasma-manager generates a JS script that recreates panels only when the config hash changes.
   - **NO `fix-floating` desktopScript** — removed because `runAlways = true` scripts cause panel recreation every boot.
   - **NO `cleanPanelViews` activation hook** — removed (was stripping plasmashellrc, no longer needed).
   - **NEVER delete `last_run_desktop_script_panels`** — forces panel recreation while plasmashell runs (SIGSEGV).
   - After panel changes, verify with: `qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'panels().forEach(function(p){print("floating=" + p.floating + " height=" + p.height)})'`
3. **Activation hooks**: use `lib.hm.dag.entryBefore [ "reloadSystemd" ]`. Be aware these run during `nrb` while the desktop may be active.
4. **KWin scripts**: packaged inline in the plasma module `let` block. Update `rev` + set `sha256 = ""` + rebuild for new hash.
5. **After changes**: run `bash scripts/update-docs.sh` if module options changed. Update `README.md` module tables if structure changed.


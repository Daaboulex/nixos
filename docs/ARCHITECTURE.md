# Architecture

Structural rules for this flake. Answers "where does a new module go?"

**See also** — the three project-standard docs have distinct scopes:

| Doc                        | Owns                                                         |
| -------------------------- | ------------------------------------------------------------ |
| **ARCHITECTURE.md** (this) | directory layout + parts-vs-home boundary + scope categories |
| **[STYLE.md](STYLE.md)**   | code style rules + option conventions + §13a placement       |
| **[BUILD.md](BUILD.md)**   | formatters, hooks, checks, tests, doc auto-regen             |

Together these three are the project's standard.

## 1. Top-level layout

```text
flake.nix                 # entry point — delegates to parts/
parts/                    # NixOS modules (system-level concerns)
home/                     # Home Manager modules (user-level concerns)
  home/modules/           #   per-tool HM modules (auto-discovered)
  home/hosts/             #   per-host HM toggle blocks + overrides
  home/lib/               #   shared helpers exposed as myLib (mkSimplePackage, themeCtx, …)
  home/home.nix           #   HM composition root
docs/                     # Real project documentation (STYLE, BUILD, OPTIONS…)
repos/                    # Independent git repos (gitignored)
scripts/                  # Admin helpers (migrate, warm-cache, etc.)
secrets/                  # agenix-encrypted secrets (.age files, gitignored; secrets.nix tracked)
```

## 2. Parts vs Home — the boundary

**System-level → `parts/`**

A module belongs in `parts/` if it requires root privilege or sets
state that applies to every user on the machine. Any of:

- `services.<daemon>.enable` — systemd system units
- `boot.*`, `hardware.*`, `networking.*`, `security.*`
- Udev rules, firewall rules, kernel modules, kernel params
- `users.users.*` (including group memberships)
- PAM, agenix secrets, LUKS, initrd

**User-level → `home/modules/`**

A module belongs in `home/modules/` if it configures user-scoped
state — per-user config files, XDG dirs, shell config, editor,
GUI theming. Any of:

- `programs.<tool>.enable` (the HM version — note these exist at
  both system and HM level; HM is preferred when available)
- `xdg.configFile.*`, `home.file.*`, `home.packages`
- `services.<daemon>` _when provided by HM_ (dbus-session services)
- `wayland.windowManager.*`, `gtk.*`, `qt.*`
- Theme wiring (`myModules.home.theme` integration)

**Escape hatch**: if a concern straddles both (e.g. goxlr — system
daemon + user GUI + user profiles), build **two** modules, one in
each tree. Each ignorant of the other. The host file composes them.

## 3. Parts — category structure

Each `parts/<category>/` is a directory of related modules. Current
categories:

| Dir                  | Purpose                                                                                                                                                                                                                                                                                                                                                                                                      |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `parts/_build/`      | Build infrastructure — treefmt, git-hooks, checks, overlays, VM tests. Private to the flake plumbing, never host-facing.                                                                                                                                                                                                                                                                                     |
| `parts/boot/`        | Boot loader, kernel selection, impermanence, hibernate.                                                                                                                                                                                                                                                                                                                                                      |
| `parts/desktop/`     | Display servers + DE-level concerns (plasma, displays, flatpak).                                                                                                                                                                                                                                                                                                                                             |
| `parts/diagnostics/` | Performance + health probes exposed as NixOS modules — turbostat (kernel-matched).                                                                                                                                                                                                                                                                                                                           |
| `parts/gaming/`      | Gaming stack — steam, gamescope, gamemode, rocksmith.                                                                                                                                                                                                                                                                                                                                                        |
| `parts/hardware/`    | Physical-device drivers + daemons that talk to hardware — CPU (amd/intel), GPU (amd/intel/nvidia), graphics, networking, power, bluetooth, pipewire, usbmuxd, acpid, upower, USB power, coolercontrol (AIO pump/fan), goxlr (external USB mixer). Bloated at ~18 files but every entry IS hardware-related; no clean split exists. If it grows past 25, consider subdirs (`hardware/cpu/`, `hardware/gpu/`). |
| `parts/input/`       | Peripherals and input stack — libinput (touchpad), ratbagd (mice), yeetmouse, Ducky keyboard, Stream Deck.                                                                                                                                                                                                                                                                                                   |
| `parts/macbook/`     | Apple-specific fixes — applesmc/hid-apple patches, mbpfan, Broadcom WiFi. Host-specific category; OK as-is because the patches don't apply to any other host.                                                                                                                                                                                                                                                |
| `parts/nix/`         | Nix daemon, nix-ld, remote-builder.                                                                                                                                                                                                                                                                                                                                                                          |
| `parts/security/`    | sshd, agenix, portmaster, hardening.                                                                                                                                                                                                                                                                                                                                                                         |
| `parts/sensors/`     | Hwmon drivers — nct6775, it87, zenpower, ryzen-smu, msr.                                                                                                                                                                                                                                                                                                                                                     |
| `parts/services/`    | Daemon services where the app is foreground for the feature — avahi, cups, earlyoom, geoclue, mullvad, sunshine, syncthing.                                                                                                                                                                                                                                                                                         |
| `parts/storage/`     | Filesystems, fstrim, btrbk.                                                                                                                                                                                                                                                                                                                                                                                  |
| `parts/tuning/`      | Performance + stability — cachyos settings, sysctls, performance, corecycler (benchmark/stress).                                                                                                                                                                                                                                                                                                             |
| `parts/vfio/`        | VFIO GPU passthrough stack — base, device-binding, session-gpu, evdev, kvmfr, hugepages, vms.                                                                                                                                                                                                                                                                                                                |

**Not a category: `parts/hosts/`.** Per-host wiring (`<hostname>/default.nix` + `flake-module.nix` + `hardware-configuration.nix`) lives under `parts/hosts/<name>/`, but hosts are not a module category — they're composition, not contract. No generic modules go there. See §8.

**Standalone top-level files** (`parts/*.nix`, not inside a category):

- `parts/flake-module.nix` — composition root (required, not negotiable).
- `parts/users.nix` — the user-management module itself, cross-cutting
  (every host uses it; no natural category because it's the _about users_
  concern, not a user-facing daemon).
- `parts/host.nix` — host tier enum (`v2`/`v3`/`v4`) that drives
  `kernel.mArch` defaults. Cross-cutting metadata, belongs at the root
  — a category would obscure that it's meta-level.

These three are the only legitimate top-levels. Any other `parts/*.nix`
is almost certainly in the wrong place; move it into a category.

## 4. When to create a new category

Create a new `parts/<name>/` directory when:

1. **≥ 3 related modules** share a concern, AND
2. None of the existing categories are a natural fit, AND
3. The name describes a shared **contract** (all modules in the dir
   do the same _kind_ of thing), not just a tag.

**Do not** create a single-file directory (e.g. dropping a single
benchmark module into a fresh `parts/foo/` with no siblings). Put the
file in an existing category or keep it top-level.

Exception: a category may launch with one file when the contract is
clear and growth is imminent (the `parts/diagnostics/` category was
seeded with `turbostat.nix` because it will gain b43-resume-verify,
audit-probes, and other observability modules that don't fit the
existing taxonomy). Document the seed-with-growth intent in the
category's first module.

## 5. When to split a category

A category is too big when:

- It exceeds ~15 files AND
- Contributors can't find a specific module within the directory in
  under ~5 seconds without grep.

Split options:

- **Subdirectories**: `parts/hardware/cpu/`, `parts/hardware/gpu/`.
  Preserves the top-level category. Flake-module imports are
  unchanged (dendritic auto-discovery recurses).
- **Sibling split**: move daemons out of `parts/hardware/` into
  `parts/services/` (e.g. `usbmuxd`, `upower`, `acpid` are services,
  not hardware drivers). Requires updating imports per-host.

## 6. Naming convention

- File name = primary package name, kebab-case: `nct6775.nix`, `cpu-amd.nix`.
- Module attr = `flake.modules.nixos.<category>-<name>` (hyphen-joined).
  So `parts/input/libinput.nix` exports `flake.modules.nixos.input-libinput`.
- Option path mirrors file layout: `myModules.input.libinput.<option>`.
- Sub-modules in a directory (`parts/vfio/session-gpu.nix`) use
  `myModules.vfio.sessionGpu` (camelCase conversion of kebab-case file).

## 7. When to move a module across categories

Moving a module is a 5-point edit:

1. `git mv parts/old-cat/foo.nix parts/new-cat/foo.nix`
2. Rename `flake.modules.nixos.old-cat-foo` → `flake.modules.nixos.new-cat-foo` inside the file.
3. Rename option path `myModules.oldCat.foo` → `myModules.newCat.foo` inside the file.
4. Update host configs that reference the old option path.
5. Update host flake-module imports (rename; exhaustiveness-exclude
   lists too).

All steps verifiable via `nix flake check` or per-host
`nix eval .#nixosConfigurations.<host>.config.networking.hostName`.

## 8. Host-exhaustiveness

Every `parts/<category>/<name>.nix` module MUST be imported in
every host's `flake-module.nix` — OR be listed in the
`# exhaustiveness-exclude:` comment block at the top of the
host's flake-module.nix. The `nixos-exhaustiveness` pre-commit
hook enforces this.

Rationale: prevents "I added a new module and forgot to wire it
into host X" bugs; also means the exclude list doubles as
host-scoped documentation of which modules intentionally don't
apply.

## 9. Cross-module dependencies

**Avoid.** Modules should not import each other or reference each
other's option paths. If two modules need to cooperate, the host
config composes them — that's the trunk, each module is a branch.

Exception: well-known system interfaces (e.g. `myModules.primaryUser`,
`myModules.host`) may be read by other modules _for defaults_,
never for behaviour. Keep these dependencies unidirectional:
downstream modules read upstream metadata, never the reverse.

## 10. Known open issues (tracked, not auto-fixed)

- **`repos/vfio-stealth-nix/module.nix` uses `myModules.vfio.stealth`.**
  Violates the "repos must be generic, no `myModules.*`" rule (memory:
  feedback_repo_self_contained). Fix = split the wrapper out: repo
  exposes `services.vfio-stealth` (generic), flake adds a thin
  `parts/vfio/stealth.nix` wrapper mapping `myModules.vfio.stealth`
  → `services.vfio-stealth`. Deferred because it's a repo-side
  refactor that needs coordinated commits across two repos.

- **`parts/vfio/vms.nix` is 1182 lines.** Candidate for split per §5
  (into `vms/default.nix` option schema, `vms/hooks.nix` libvirt
  prepare/release scripts, `vms/nixvirt.nix` domain XML builder), but
  the internals are structurally entangled — shared `let` bindings
  referenced by PCI parser + prepareScript + releaseScript + domain
  builder. A safe split needs a VFIO passthrough smoke-test after the
  refactor (domain XML reordering can break libvirt restart). Defer
  to a dedicated session with VM testing available.

## 11. Adding a new module — checklist

1. Decide: system-level (`parts/`) or user-level (`home/modules/`)?
2. Pick the category (see §3); create one only if §4 applies.
3. File name = primary package name (§6).
4. Module shape: `STYLE.md §6.1`.
5. Option path mirrors file layout (§6).
6. Import into EVERY relevant host's flake-module.nix (§8).
7. If host-specific, add to `exhaustiveness-exclude` list of hosts
   it doesn't apply to.
8. `nix flake check --no-build` passes before commit.
9. Pre-commit hooks pass — especially `nixos-exhaustiveness`.
10. Update `docs/OPTIONS.md` (auto-regen via `update-docs` hook).

See also `docs/STYLE.md` for code-style rules.

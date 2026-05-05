# Nix Style & Standards (2026-04-15)

**Scope.** Coding standards for this repo (`~/Documents/nix`). Applies to every `.nix` file under `parts/`, `home/`, `flake.nix`, and `docs/*.nix.example` templates. **Does not** apply to `repos/**` (vendored third-party).

**See also** — the three project-standard docs have distinct scopes:

| Doc                                    | Owns                                                         | Answers                                          |
| -------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------ |
| **STYLE.md** (this)                    | code style rules + option conventions + §13a placement       | "how do I write this module's code?"             |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | directory layout + parts-vs-home boundary + scope categories | "where does this new module go?"                 |
| **[BUILD.md](BUILD.md)**               | formatters, hooks, checks, tests, doc auto-regen             | "what runs on `git commit` / `nix flake check`?" |

**Philosophy.** Self-contained, self-named, dendritic, non-interdependent modules. Every file either declares options + config, or is a pure helper function. No cross-module imports. Shared state flows through `myModules.*` options, never through `specialArgs` or file imports.

---

## 0. RFC 2119 keywords

- **MUST / MUST NOT** — hard rule, CI-enforceable.
- **SHOULD / SHOULD NOT** — default, exceptions need an inline `# Why:` comment.
- **MAY** — allowed, no preference.

---

## 1. Module shape

### 1.1 Standard module template

Every `home/modules/<name>/default.nix` and `parts/**/<name>.nix` that contains options+config **MUST** match one of these shapes.

**Shape A — NixOS flake-module (dendritic):**

```nix
# <name> — one-line purpose.
#
# Contract:
#   Options:  myModules.<path>.*
#   Sets:     <top-level attrs this module contributes to>
#   Depends:  <cross-cutting options this reads; NEVER file imports>
#
# Rationale: <why this module exists as a distinct concern — one paragraph>.
{ inputs, ... }:
{
  flake.modules.nixos.<name> =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.myModules.<path>;
    in
    {
      _class = "nixos";

      options.myModules.<path> = {
        enable = lib.mkEnableOption "<subject>";
        # other options…
      };

      config = lib.mkIf cfg.enable {
        # …
      };
    };
}
```

**Shape B — Home-manager module:**

```nix
# <name> — one-line purpose.
#
# Contract: as above.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myModules.home.<name>;
in
{
  options.myModules.home.<name> = {
    enable = lib.mkEnableOption "<subject>";
    # …
  };

  config = lib.mkIf cfg.enable {
    # …
  };
}
```

**Shape C — Trivial wrapper (use the helper):**

```nix
import ../../lib/mkSimplePackage.nix {
  name = "<name>";
  description = "<subject>";
}
```

### 1.2 Rules

1. **MUST** qualify every `lib` helper: `lib.mkOption`, `lib.mkIf`, `lib.types.*`. `with lib;` is **forbidden** (`deadnix` will flag).
2. **MUST** start the file with the 6-line comment block (what / contract / rationale). Helper-imports (Shape C) are exempt — the helper encapsulates the contract.
3. **MUST** bind `cfg` in `let` inside `config = let … in { … };` for non-trivial modules to keep option-tree access lazy. Shape B's top-level `let cfg = …` is acceptable for single-purpose modules.
4. **SHOULD NOT** use `imports = [ ./sub.nix ];` _unless_ the module is a documented umbrella that composes sub-modules (current legit cases: `home/modules/{macbook,neovim,plasma,flatpak,goxlr}`). Sub-modules inside an umbrella **MUST** live in the same directory.
5. **SHOULD** prefer the `_class` annotation for flake-modules (makes flake-parts class-check strict).

### 1.3 Anti-patterns (forbidden)

- `with lib;` anywhere.
- `throw "msg"` at module top (blocks all other error reporting). Use `assertions`.
- `lib.mdDoc "..."` — deprecated; descriptions are already CommonMark.
- `config = lib.mkMerge (lib.mapAttrsToList … cfg.X);` at top level — triggers infinite recursion. Push the `mkMerge` down one level: `config.systemd.services = lib.mkMerge (…);`.
- Cross-module file imports: `imports = [ ../theme/default.nix ]`. Share state via `config.myModules.theme.*` options read through the module system.

---

## 2. Options

### 2.1 Naming

- Path: `myModules.<area>.<feature>.<field>`. `<area>` ∈ {`boot`, `hardware`, `services`, `security`, `tuning`, `gaming`, `macbook`, `desktop`, `home`, …}.
- Leaf names: `camelCase`. Multi-word with hyphens only when mirroring an upstream option (`x11-bell`).
- Booleans: positive sense (`enableHardening`, not `disableHardening`).
- **File names:** `parts/**/*.nix`, `home/modules/*/`, `scripts/*.{sh,nix}` → kebab-case. Underscore prefix (`_build`, `_vms-lib.nix`) reserved for internal-helper files excluded from auto-discovery.
- **Doc file names** (`docs/*.md`): **ALLCAPS-KEBAB.md** exclusively.
  No lowercase filenames. See `docs/DOC-STYLE.md` §1 for rationale.

### 2.2 Declarations

1. **MUST** use `lib.mkEnableOption "<subject>"` for every on/off toggle defaulting to `false`. Subject is a short noun phrase, **not** "enable the thing" (reads as "enable enable the thing").
2. **MUST** fall back to `lib.mkOption { type = lib.types.bool; default = true; description = "…"; }` when an option defaults to `true`. `mkEnableOption` cannot express that.
3. **MUST** use `lib.mkPackageOption pkgs "<attr>" { }` for package overrides, not `mkOption { type = types.package; default = pkgs.<x>; }`.
4. **MUST** provide a `description` on every non-enable option. Short (one sentence + optional expansion). Plain Markdown. Use backticks for option names in the description.
5. **SHOULD** provide `example = lib.literalExpression "…"` when the default is not illustrative of real usage.
6. **SHOULD** use `lib.types.enum [ … ]` instead of `types.str` when the set of valid values is known.

### 2.3 Defaults / priority

| Priority               | When                                                                                              |
| ---------------------- | ------------------------------------------------------------------------------------------------- |
| plain `= value` (100)  | **Host config** (`parts/hosts/*/default.nix`, `home/hosts/*/default.nix`) — hosts express intent. |
| `lib.mkDefault` (1000) | **Shared modules** (`myModules.*`) — so hosts can override.                                       |
| `lib.mkForce` (50)     | Rarely. **MUST** include an inline `# Why: …` one-liner explaining why override is needed.        |
| `lib.mkOverride N`     | Only for specific priority gaps; **MUST** be documented.                                          |

**Rule:** if you wrote `mkForce` without a `# Why:` comment adjacent, the linter fails.

### 2.4 Submodules

For multi-instance configuration (N named things with options), use:

```nix
type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
  options = { … };
  config = {
    # 'name' is the attrset key; promote to a field for ergonomics
    someField = lib.mkDefault name;
  };
}));
```

Lift the submodule into a `let` if referenced from multiple options.

---

## 3. Assertions & error messages

### 3.1 Where

- **`assertions = [ … ]`** inside a module's `config` block — for user misconfiguration (wrong combination of options). Accumulates across the tree; `nixos-rebuild` surfaces all failures at once.
- **`lib.throwIf cond msg value`** — only inside `home/lib/` and `parts/_build/` helpers, for library-author invariants.
- **`lib.warn` / `lib.warnIf`** — deprecation paths where the old option still works but will go away.

### 3.2 Message format

```text
myModules.<option.path>: <what is wrong>. <why it is wrong>. <how to fix>.
```

Example:

```nix
assertions = [
  {
    assertion = !(cfg.backend == "remote" && !config.myModules.networking.enable);
    message = ''
      myModules.programs.foo.backend: 'remote' requires myModules.networking.enable = true.
      Enable networking or switch backend to 'local'.
    '';
  }
];
```

Message **MUST** contain:

1. Full option path.
2. What combination is invalid.
3. At least one concrete fix.

### 3.3 Laziness

Assertions **SHOULD** live inside `config = lib.mkIf cfg.enable { assertions = [ … ]; }` so they don't fire when the module is disabled.

---

## 4. Comments & documentation

### 4.1 Required module docstring

Every module file **MUST** begin with at least a one-line docstring of the form `# <name> — <one-line purpose>.`. This is the minimum enforced by the `check-module-docstring` hook and is sufficient for simple modules.

The full six-line Contract + Rationale block (§1.1 Shape A/B) is **RECOMMENDED** when any of these apply:

- Module declares 3+ options.
- Module depends on cross-cutting options (reads `myModules.<X>` from other modules).
- Module uses `lib.mkForce`, `lib.mkOverride`, or other priority overrides.
- Module has non-obvious rationale that the code doesn't already state.

Modules < 20 lines and using `mkSimplePackage` are exempt from even the one-line form — the helper itself carries the documentation burden.

Do **not** bulk-backfill the six-line form onto simple modules. Migrate at edit-time: when a module gains enough complexity to warrant the fuller block, add it alongside the substantive change.

### 4.2 Inline rationale

`# Why: …` one-liner **REQUIRED** next to:

- Any `lib.mkForce`.
- Any suppressed deadnix / statix warning.
- Any `lib.mkIf cfg.enable && <upstream-bug-workaround>` branch.
- Any `pkgs.lib.versionOlder` / `lib.versionAtLeast` gate against a version.
- Any commented-out code (else delete it).

### 4.3 No ASCII section banners in modules

The `# === ...` banner style is allowed **only** in `parts/hosts/<name>/default.nix` (the exhaustive reference host files). Module files use the docstring and whitespace.

### 4.4 Option descriptions

- Plain Markdown (CommonMark).
- Backticks around option paths and code.
- `**bold**` for warnings.
- `example = lib.literalExpression "..."` for non-scalar defaults.
- **Never** `lib.mdDoc` — removed.

---

## 5. Helpers & reuse

### 5.1 When to extract a helper

Extract only when **ALL THREE** hold:

1. 3+ call sites exist (not 2, not "might be useful").
2. The signature is stable (won't change per-consumer).
3. The helper earns a docstring and an example.

"Three similar lines > one premature abstraction."

### 5.2 Existing helpers

Exposed via `flake.lib.*` and injected into every module as `myLib` (see `parts/_build/lib.nix`):

- `mkSimplePackage` — trivial HM package wrappers (78 callers).
- `themeCtx` — gathered theme context (`hasTheme`, colour palette, `when` guard).
- `cap` — capitalize first letter (3 callers: eza, tealdeer, csvlens).
- `withStdenvCC` — force-inject `stdenv.cc` into a derivation's `nativeBuildInputs` (fixes strictDeps + empty `nativeBuildInputs`; single-user class-of-bug helper).
- `mkSettingsOption` — factory for `settings = attrsOf anything` override options.
- `mergeSettings` — named-arg wrapper around `lib.recursiveUpdate` catching positional-arg footguns.

### 5.3 Expose via `flake.lib`

Helpers **SHOULD** be exposed at `flake.lib.<name>` so they are (a) reusable inside `parts/`, (b) testable, (c) visible in `nix eval .#lib`.

### 5.4 Typed option factory (optional)

If the repo grows past 100 total `myModules.*` options, introduce `mkMyOption` enforcing description presence:

```nix
# home/lib/mkMyOption.nix
{ lib }: { type, default ? null, description, example ? null }:
  lib.mkOption ({ inherit type description; }
    // lib.optionalAttrs (default != null) { inherit default; }
    // lib.optionalAttrs (example != null) { inherit example; });
```

Skip until needed.

---

## 6. Flake-parts surface

### 6.1 Module export hierarchy

**MUST** expose modules under the **class-hierarchical form**:

```nix
flake.modules.nixos.<name>       # NixOS modules
flake.modules.homeManager.<name> # Home-Manager modules
flake.lib.<name>                 # pure helper functions
```

The legacy `flake.nixosModules.<name>` path is **deprecated** in this repo. During migration, export under both paths with an alias:

```nix
flake.nixosModules.<name> = flake.modules.nixos.<name>;  # legacy alias
```

Drop the alias after one rebuild cycle.

### 6.2 `perSystem` arguments

Destructure only what's used; rely on `...` to silence deadnix on the rest:

```nix
perSystem = { config, pkgs, lib, ... }: { … };
```

### 6.3 Host wiring

Hosts (`parts/hosts/<name>/flake-module.nix`) **MUST** reference modules via `inputs.self.modules.nixos.<name>`, not `inputs.self.nixosModules.<name>`, after the migration lands.

---

## 7. Home-manager

### 7.1 Delegate to native `programs.X` inside wrappers

**MUST** delegate to native HM `programs.X` / `services.X` inside the module body:

```nix
config = lib.mkIf cfg.enable {
  programs.foo.enable = true;                                   # native HM toggle
  programs.foo.settings = lib.mkMerge [ defaults cfg.extra ];   # merge user overrides
};
```

**Do NOT delete trivial pass-through wrappers** (`myModules.home.<x>.enable` → `programs.<x>.enable = true;`). This repo intentionally preserves the uniform `myModules.home.*` namespace across every HM module:

1. **Discoverability** — one option path pattern, nowhere else to look.
2. **`hm-exhaustiveness` coverage** — every host must declare every `myModules.home.*.enable`; bypassing to native `programs.X.enable` would remove the module from that discipline.
3. **Future extensibility** — options can be added later without changing host-facing API.

~15 lines per wrapper is a worthwhile tax for the uniformity.

### 7.2 `xdg.configFile` preference

**MUST** use `xdg.configFile."<path>"` for anything under `$XDG_CONFIG_HOME` (nearly everything). Reserve `home.file` for files that **must** live elsewhere (e.g. `.bashrc`, `~/.ssh/config`).

### 7.3 Activation DAG

Use `lib.hm.dag.entryAfter [ "writeBoundary" ]` for post-link steps. `entryBefore` is rare and SHOULD have a `# Why:` comment.

Scripts **MUST** use the HM `run` shell function so `--dry-run` works:

```nix
home.activation.foo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  run ${pkgs.foo}/bin/foo --check
'';
```

### 7.4 Cross-host variation via typed host metadata

**SHOULD** expose a typed tier in `myModules.host`:

```nix
# parts/hosts/<host>/default.nix (NixOS side)
myModules.host = {
  tier = "v2";  # or "v3"
};
```

HM modules read via `osConfig.myModules.host.tier`, **not** `osConfig.networking.hostName` string comparison. Hostname is a free-form label; tier is a declared contract.

Acceptable existing uses of hostname (for `nixdHost` LSP completion attr lookup) remain permissible — they don't gate behavior, they pick a nix attr.

---

## 8. Format & lint toolchain

### 8.1 Current toolchain (keep)

- **nixfmt (RFC 166)** — enforced via treefmt-nix.
- **deadnix** — with `no-lambda-pattern-names = true` and `no-underscore = true` so flake-parts `perSystem` and `@args: { … }` bindings don't false-trigger.
- **statix** — default rule set. No repo-wide config file unless a false positive appears.
- **shellcheck** / **shfmt** — for inline shell.
- **prettier** — JSON/YAML/Markdown.

### 8.2 Pre-commit hooks (git-hooks.nix)

Current full set (source: `parts/_build/git-hooks.nix`): `auto-format`, `check-assertion-format`, `check-behind-remote`, `check-mkforce-comment`, `check-module-docstring`, `check-no-roadmap-in-docs`, `check-no-with-lib`, `check-placement`, `check-scrub-tokens`, `check-secrets-leak`, `hm-exhaustiveness`, `nix-eval-check`, `nixos-exhaustiveness`, `update-docs`. **All custom hooks** MUST be `pkgs.writeShellApplication` (not `writeShellScript`) so they get shellcheck at build and `set -euo pipefail` automatically.

### 8.3 New enforcement (added by this standard)

Add the following project-local checks. Each is a `pkgs.writeShellApplication` in `parts/_build/checks/`:

- **`check-module-docstring`** — every non-helper `.nix` module file has the 6-line comment header. Exempt: files matching `home/lib/`, `parts/_build/`, and files importing `mkSimplePackage`.
- **`check-mkforce-comment`** — every `lib.mkForce` has a `# Why:` adjacent comment.
- **`check-assertion-format`** — every `{ assertion = …; message = …; }` message begins with `"myModules.…:"`.
- **`check-no-with-lib`** — forbid `with lib;`.

Wire into `git-hooks.nix` under `pre-commit.hooks.<name>`.

### 8.4 CI

`nix flake check --all-systems` runs every hook plus eval. Should pass on every merged commit; skip locally only with explicit `SKIP=<hook>` and a commit message note.

### 8.5 Scrub policy

Tokens, patterns, and context-aware exemptions defined in `~/.ai-context/scripts/scrub-config.json` (canonical catalog; consumed by `~/.ai-context/.pre-commit-scrub.sh`, `scrub-sanitize.js`, `scrub-discover.js`, `scrub-for-publish.sh`).

Enforced for `Daaboulex/nixos` by the `check-scrub-tokens` pre-commit hook (`parts/_build/git-hooks.nix` → `parts/_build/checks/check-scrub-tokens.nix`). Hook reads `forbidden_tokens` + `forbidden_patterns` + `allow_in_docs` + `context_allowlist`, fails commit on any unallowed hit, exits 0 if config absent (fresh clone). Bypass: `git commit --no-verify` (single-maintainer trust model; CI gate deferred per ROADMAP Phase Q).

See `docs/REPO-STANDARD.md` §"Why these rules exist" for the complementary scaffold-lockdown contract on satellite `repos/*`.

---

## 9. Secrets (already adopted)

Repo uses **agenix**. Standards:

- Per-secret `.age` files in `secrets/` (gitignored, Syncthing-synced).
- Encryption rules: `secrets/secrets.nix` (tracked — maps host public keys to secret files).
- Identity: host SSH key at `/etc/ssh/ssh_host_ed25519_key`.
- Access: `config.age.secrets.<name>.path` — never the raw `.age` file.
- Declare secrets via `myModules.security.agenix.secrets.<name> = {};`.

---

## 10. Commit conventions

### 10.1 Conventional Commits

Format: `<type>(<scope>): <subject>`

- `type` ∈ `feat`, `fix`, `refactor`, `perf`, `chore`, `docs`, `test`, `revert`.
- `scope` is the top-level area (`hm`, `macbook`, `hosts`, `services`, `boot`, `hm,neovim`, …).
- `subject` imperative, ≤ 72 chars, no trailing period.

### 10.2 Body

- Blank line after subject.
- Body explains **why**, not what. The diff is the what.
- Wrap at 80 cols.
- Reference sources / links for research-driven changes (date them).

### 10.3 Signed

Git signing is configured. **NEVER** modify git config.
**NEVER** add `Co-Authored-By` trailers.

---

## 11. Host configs

### 11.1 `parts/hosts/<name>/default.nix`

- "Exhaustive reference" style: list **every** `myModules.*` option the module tree exposes, even if left at default.
- Mark defaults with `# (default)` so the diff is obvious when an option is intentionally overridden.
- Plain assignment (`= value`) — hosts are the authoritative layer.
- ASCII section banners (`# === Hardware ===`) allowed here (and **only** here).

### 11.2 `parts/hosts/<name>/flake-module.nix`

- Only imports and wiring. No logic. No settings.

### 11.3 `home/hosts/<name>/default.nix`

- Mirror of above for HM side.
- `hm-exhaustiveness` hook enforces listing every HM module's enable.
- **Toggle syntax:**
  - `name.enable = true;` (flat) when only the `enable` sub-option is set for this host.
  - `name = { enable = true; <subopt> = …; };` (nested) when the host also sets sub-options of the module.
  - Never mix both forms for the same module in one host file.

---

## 12. Testing

### 12.1 When to add tests

Rule of thumb: if a regression in this module costs > 15 min to diagnose via rebuild, add a test. Otherwise `nix flake check` + the hook stack is enough.

### 12.2 Smoke tests per host tier (optional)

One `pkgs.nixosTest` per host tier (v2, v3) asserting:

- HM activation exits 0.
- A handful of expected `xdg.configFile` entries exist in the output.
- Critical services start (e.g. `mbpfan` on v2, `sunshine` on v3).

### 12.3 Eval profiling

Run `NIX_SHOW_STATS=1 nixos-rebuild dry-build …` periodically. If `nrThunks` or `gc.totalBytes` regresses > 20%, investigate — usually a `let` moved too high or a `rec { … }` fixed-point snuck in.

---

## 13. `myModules.*` namespace ownership

Reserved top-level keys (MUST NOT collide):

```text
myModules.boot         myModules.hardware     myModules.services
myModules.security     myModules.tuning       myModules.gaming
myModules.macbook      myModules.desktop      myModules.home
myModules.host         myModules.theme        myModules.primaryUser
myModules.nix          myModules.users        myModules.storage
myModules.sensors      myModules.input        myModules.diagnostics
myModules.vfio
```

Adding a new top-level key requires a commit with `refactor(schema):` scope and an update to this document.

---

## 13a. Placement rule

**Contract (one sentence):** the option scope path IS the taxonomy; the directory path MUST reflect it.

Formally, the enforced rules are:

```text
parts/<scope>/<name>.nix           →  options.myModules.<scope>.*      (any leaf)
parts/<scope>.nix                  →  options.myModules.<scope>.*      (top-level schema)
home/modules/<leaf>/default.nix    →  options.myModules.home.<leaf>.*  (dirname == leaf)
home/modules/<u>/<sub>.nix         →  options.myModules.home.<u>.<sub>.*   (umbrella nesting, STYLE §1.1.4)
```

Parts-side rule is **scope-match only** — multiple files under `parts/<scope>/` may
contribute options to the same `myModules.<scope>.*` namespace. This mirrors upstream
nixpkgs (e.g. `services.networking.*` is split across many files) and preserves the
atomic per-concern file decomposition without forcing a separate option leaf per file.

Home-side umbrella rule is **strict nesting** — sub-modules (`home/modules/<u>/<sub>.nix`)
MUST declare their options under `myModules.home.<u>.*`, not as sibling top-level leaves
`myModules.home.<u>-<sub>`.

File names are kebab-case; option leaves are camelCase (STYLE §2.1). Names follow their
own convention — the hook does not enforce file↔leaf name correspondence, only scope
placement.

### 13a.1 Taxonomy ladder — how to pick `<scope>`

**Primary classifier: mechanism / layer, not intent.** Tiebreaker ladder (upstream NixOS convention — first match wins):

| Order | Question                                             | Scope                               |
| ----- | ---------------------------------------------------- | ----------------------------------- |
| 1     | Hardware-specific (GPU, CPU, sensor, peripheral)?    | `hardware` (or `macbook` if vendor) |
| 2     | Bootloader / kernel / initramfs / LUKS?              | `boot`                              |
| 3     | Kernel-tuning / scheduler / sysctl / mitigations?    | `tuning`                            |
| 4     | Observability / diagnostics tooling?                 | `diagnostics`                       |
| 5     | Virtualization (host or guest)?                      | `vfio`                              |
| 6     | Userspace daemon (always-on)?                        | `services`                          |
| 7     | Security mechanism (MAC, auth, audit, PAM, secrets)? | `security`                          |
| 8     | Input / peripheral handling?                         | `input`                             |
| 9     | Desktop session / compositor?                        | `desktop`                           |
| 10    | Sensor / hwmon driver?                               | `sensors`                           |
| 11    | Storage / filesystem / backup?                       | `storage`                           |
| 12    | Nix itself (daemon, builder, sandbox)?               | `nix`                               |
| 13    | Schema-wide (host identity, user accounts)?          | top-level `parts/<name>.nix`        |
| 14    | User-facing program / CLI / TUI / GUI?               | `home/modules/<name>/` (HM side)    |

**Tiebreaker: mechanism wins over intent.** A firewall is `services/`, not `security/`, because it touches networking. A session-token storage module is `services/` even if driven by compliance requirements.

### 13a.2 Exempt from the rule

- `parts/_build/**` — build tooling.
- `parts/hosts/**`, `home/hosts/**` — authoritative host layers.
- `home/lib/**` — pure helpers.
- `flake.nix`, `**/flake-module.nix` — composition roots.
- Base name begins with `_` (e.g. `_vms-lib.nix`) — private helper.
- Files with no `options.myModules.*` and no `mkSimplePackage` import — pure package specs; covered indirectly by the wrapper that consumes them.

### 13a.3 Enforcement

`check-placement` hook (see `parts/_build/checks/check-placement.nix`) runs on every `git commit` touching `parts/**/*.nix` or `home/modules/**/*.nix`. On mismatch it prints the full path, the expected scope, the actual scope, and a fix hint.

---

## 14. Philosophy guardrails

- **Self-contained**: a module's behavior is determined by its own options + (optionally) cross-cutting state read through the option tree. No relative-path imports of sibling modules.
- **Self-named**: `parts/services/mullvad.nix` sets `flake.modules.nixos.services-mullvad`. Path and name agree.
- **Dendritic**: one file = one concern = one module. No registry files listing everything; auto-import via `readDir` (or `import-tree` after §15).
- **Non-interdependent**: if you delete any one module, the rest still evaluate. The `enable = false` test is a proxy: disabling module X MUST NOT break module Y.

---

## 15. Forward migrations (separate execution plan)

Items identified by the research spec that changed file contents (not just style). Completed items archived here for history; pending items tracked in `.ai-context/.superpowers/`.

1. ✅ `flake.nixosModules.*` → `flake.modules.nixos.*` — complete.
2. `builtins.readDir` auto-import → `vic/import-tree` with `_`-prefix skip — deferred, current `readDir` approach works.
3. ✅ Typed `myModules.host.tier` enum replacing implicit hostname gating — complete (drives `kernel.mArch` default).
4. ✅ `mkSimplePackage` exposed via `flake.lib` — complete (all 6 helpers exposed, pre-applied, injected via `myLib` specialArg).
5. Delete HM wrappers that only set `programs.X.enable = true;` — per-case; retained where toggle gating adds value.
6. ✅ `hm-exhaustiveness` hook → `writeShellApplication` — complete.
7. ✅ New enforcement hooks (§8.3) — complete (check-assertion-format, check-mkforce-comment, check-module-docstring, check-placement, check-no-with-lib, check-no-roadmap-in-docs, check-behind-remote all shipped).

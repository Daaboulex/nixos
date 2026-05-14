# Contributing

## Adding a NixOS Module

1. Create `parts/<scope>/<name>.nix` following [Shape A](docs/STYLE.md) from the style guide.
2. The scope must match the mechanism-first taxonomy ladder in `docs/STYLE.md` §13a.
3. Add `inputs.self.modules.nixos.<scope>-<name>` to each host's `flake-module.nix`, or add the module name to the `exhaustiveness-exclude` comment if it doesn't apply to that host.
4. Add option toggles to each host's `default.nix`.

## Adding a Home Manager Module

1. Create `home/modules/<name>/default.nix` following [Shape B](docs/STYLE.md) from the style guide.
2. Options go under `myModules.home.<name>`.
3. Add the toggle to every `home/hosts/*/default.nix` (enforced by the `hm-exhaustiveness` hook).

## Coding Standards

Read [`docs/STYLE.md`](docs/STYLE.md) before making changes. Key rules:

- No `with lib;` — use `lib.mkOption`, `lib.types.*` explicitly.
- Every `lib.mkForce` outside host configs needs a `# Why:` comment.
- Assertion messages must start with `myModules.<path>:`.
- Modules > 10 lines should have a docstring: `# <name> — <purpose>.`

## Before Committing

```bash
nix develop  # Enter devShell with pre-commit hooks
```

14 pre-commit hooks run automatically on `git commit`. If a hook fails, read the error — it tells you exactly what to fix. Do not bypass with `--no-verify`.

Fast validation without committing:

```bash
nrb --check              # Evaluate all configs (~10s)
nix flake check --no-build  # Run all checks except builds
nix flake check          # Full suite including VM tests
```

## Documentation

- Operator commands, hooks, and test details: [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md)
- Architecture and directory layout: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- Option reference: `nix build .#docs` (builds the documentation site)

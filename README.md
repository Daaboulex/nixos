# NixOS Flake Configuration

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Modular NixOS flake for my fleet, built on [flake-parts](https://github.com/hercules-ci/flake-parts). Every feature is an independent, toggleable module under the `myModules.*` option namespace.

**Architecture — dendritic:** each module owns its options, has no cross-module imports, and shares state only through the option tree. Adding or removing a module never breaks another. Browse everything with `nix flake show`. Conventions (file placement, naming, comment style, cross-module isolation) are machine-enforced by the pre-commit hooks in `parts/_build/`; each hook's error message states its rule.

## Hosts

| Host              | CPU                     | Arch    | Role                                                                                  |
| ----------------- | ----------------------- | ------- | ------------------------------------------------------------------------------------- |
| `ryzen-9950x3d`   | Zen 5 9950X3D (16C/32T) | x86_64  | Workstation · VFIO/GPU passthrough host · build **server** · Secure Boot (lanzaboote) |
| `macbook-pro-9-2` | Ivy Bridge i5-3210M     | x86_64  | Laptop · build **client** (offloads to ryzen) · hibernate                             |
| `pixel-9-pro`     | Tensor G4               | aarch64 | NixOS-on-AVF (Android VM) · aarch64 builder                                           |

Per-host facts (kernel, tuning, hardware) live in each `parts/hosts/<host>/default.nix`.

## Build & deploy

`nrb` is a shell function (defined in `home/modules/zsh/nrb-functions.nix`, available in interactive shells) wrapping `nixos-rebuild`/`nix` with this fleet's conventions:

```bash
nrb                     # build + switch THIS host (preserves the booted specialisation)
nrb --spec <name>       # activate a specific specialisation; --base forces the base config
nrb --update            # update all inputs, then build + switch
nrb --update-no-kernel  # update only inputs that won't trigger a kernel rebuild
nrb --dry               # build + show diff, don't activate
nrb --boot              # build + activate on next boot
nrb --check             # evaluate every config without building (fast)
nrb --deploy <host>     # build + push + activate on another host over SSH
nrb --sync <host>       # exact checksum-mirror this flake tree to host:~/Documents/nix
nrb --list / --help     # configurations + deploy targets / canonical reference
nix flake check         # full suite incl. QEMU VM tests — run on ryzen/CI, NOT the laptop
```

Routine local sanity is `nrb --check` (pure eval, no build).

## Layout

```
flake.nix            Inputs + flake-parts entry point
parts/               NixOS modules — auto-imported as flake.modules.nixos.<area>-<name>
  hosts/<host>/      Per-host wiring (default.nix · flake-module.nix · disko.nix where applicable)
  _build/            Build infra: checks · tests · git-hooks · treefmt · overlays · lib
lib/                 myLib helpers (mkSimplePackage, themeCtx, mergeSettings, mkSpecialisations, …)
home/                Home-Manager
  modules/<tool>/    Per-tool modules (myModules.home.<tool>), auto-imported
  hosts/<host>/      Per-host HM wiring
repos/               External flake inputs incl. site (private fleet registry; git-ignored, not pushed)
scripts/             Install + maintenance scripts
```

## Adding a module

- **System feature** → `parts/<area>/<name>.nix` exporting `flake.modules.nixos.<area>-<name>`, options under `myModules.<area>.<name>`.
- **User tool** → `home/modules/<name>/default.nix`; a plain package is `myLib.mkSimplePackage { name = "<name>"; package = p: p.<pkg>; }`.

Enable it per host. Placement and host coverage are enforced by the `check-placement` and exhaustiveness hooks; the scope-picker taxonomy lives atop `parts/_build/checks/check-placement.nix`.

## Secrets

[agenix](https://github.com/ryantm/agenix), encrypted to each host's SSH host key. The encrypted `*.age` blobs and the agenix recipient rules live in the private `site` registry (`repos/site/secrets/`, never pushed) — `myModules.security.agenix.secretsRoot` defaults to `inputs.site + /secrets`. Nothing secret lives in this public repo.

## site input

`repos/site` is a private, local-only (Syncthing-synced) git repo holding fleet identity (per-host IP/SSH keys/syncthing ids) and the agenix secrets. It is git-ignored here and never pushed, so the `site` flake input fetches it as its own git repo (`git+file://…/repos/site`) rather than a relative path. The path is valid on every fleet host; a host with a different `$HOME` rebuilds via `nrb`, which supplies `--override-input site …` automatically. A clone without `site` cannot evaluate the hosts that consume it.

## License

[MIT](LICENSE)

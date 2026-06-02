# NixOS Flake Configuration

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Modular NixOS flake for my fleet, built on [flake-parts](https://github.com/hercules-ci/flake-parts). Every feature is an independent, toggleable module under the `myModules.*` option namespace.

**Architecture — dendritic:** each module owns its options, has no cross-module imports, and shares state only through the option tree. Adding or removing a module never breaks another. Browse everything with `nix flake show`.

## Hosts

| Host              | CPU                     | Arch    | Role                                                                                  |
| ----------------- | ----------------------- | ------- | ------------------------------------------------------------------------------------- |
| `ryzen-9950x3d`   | Zen 5 9950X3D (16C/32T) | x86_64  | Workstation · VFIO/GPU passthrough host · build **server** · Secure Boot (lanzaboote) |
| `macbook-pro-9-2` | Ivy Bridge i5-3210M     | x86_64  | Laptop · build **client** (offloads to ryzen) · hibernate                             |
| `pixel-9-pro`     | Tensor G4               | aarch64 | NixOS-on-AVF (Android VM) · aarch64 builder                                           |

Per-host facts (kernel, tuning, hardware) live in each `parts/hosts/<host>/default.nix`.

## Build & deploy

```bash
nrb                     # build + switch THIS host
nrb --update            # update all inputs, then build + switch
nrb --update-no-kernel  # update only inputs that won't trigger a kernel rebuild
nrb --dry               # build + show diff, don't activate
nrb --boot              # build + activate on next boot
nrb --check             # evaluate every config without building (fast)
nrb --deploy <host>     # build + push + activate on another host over SSH
nrb --sync <host>       # exact checksum-mirror this flake tree to host:~/Documents/nix
nrb --list              # list configurations + deploy targets
nrb --help              # canonical reference
nix flake check         # full suite incl. ~10 QEMU VM tests — run on ryzen or CI, NOT the laptop
```

Routine local sanity is `nrb --check` (pure eval, no build). `nix flake check` boots VM tests and is intended for the build server / CI, not the Ivy Bridge laptop.

## Layout

```
flake.nix            Inputs + flake-parts entry point
parts/               NixOS modules — auto-imported as flake.modules.nixos.<area>-<name>
  hosts/<host>/      Per-host wiring: default.nix · flake-module.nix · hardware-configuration.nix · disko.nix
  _build/            Build infra: checks · tests · git-hooks · treefmt · overlays · lib
home/                Home-Manager
  modules/<tool>/    Per-tool modules (myModules.home.<tool>), auto-imported
  lib/               myLib helpers (mkSimplePackage, themeCtx, mergeSettings, …)
  hosts/<host>/      Per-host HM wiring
secrets/             agenix — secrets.nix (tracked recipients) · *.age (gitignored)
repos/               External flake inputs incl. site (private fleet registry)
scripts/             Install + maintenance scripts
```

## Adding a module

- **System feature** → `parts/<area>/<name>.nix` exporting `flake.modules.nixos.<area>-<name>`, with options under `myModules.<area>.<name>`.
- **User tool** → `home/modules/<name>/default.nix`; a plain package is just `myLib.mkSimplePackage { name = "<name>"; package = p: p.<pkg>; }`.

Enable it per host. File placement (path ⟺ option scope) and host coverage are enforced by the `check-placement` and exhaustiveness pre-commit hooks — each hook's error states the rule (the scope-picker taxonomy lives atop `parts/_build/checks/check-placement.nix`).

## Adding a host

Create `parts/hosts/<name>/{flake-module.nix, default.nix, hardware-configuration.nix}` and `home/hosts/<name>/default.nix`, then add the host's identity (IP, SSH keys, syncthing id) to `repos/site`.

## Secrets

[agenix](https://github.com/ryantm/agenix), encrypted to each host's SSH host key. Recipients live in `secrets/secrets.nix` (tracked, public keys only); encrypted blobs are `secrets/*.age` (gitignored). Edit with `agenix -e secrets/<name>.age`.

## Reusing modules elsewhere

Modules are exported individually (no `.default`):

```nix
{
  imports = [ inputs.<this>.modules.nixos.hardware-pipewire ];
  myModules.hardware.pipewire.enable = true;
}
```

## License

[MIT](LICENSE)

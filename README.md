# NixOS Flake Configuration

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Modular NixOS flake for three hosts, built on [flake-parts](https://github.com/hercules-ci/flake-parts). Every feature is an independent, toggleable module under the `myModules.*` option namespace.

**Architecture:** dendritic — each module owns its options, has no cross-module imports, and shares state only through the option tree. Adding or removing a module never breaks another.

## Using These Modules

Import individual modules in your flake. See [`docs/USAGE.md`](docs/USAGE.md) for full instructions.

```nix
{
  inputs.fahlke-nix.url = "github:Daaboulex/nixos";
}

# In your NixOS config:
{
  imports = [ inputs.fahlke-nix.modules.nixos.hardware-pipewire ];
  myModules.hardware.pipewire.enable = true;
}
```

74 NixOS modules + 152 Home Manager modules + 6 library helpers. No `.default` — import what you need.

Browse all modules: `nix flake show github:Daaboulex/nixos`

## Hosts

| Host              | CPU                 | Arch    | Kernel                              | Notes                              |
| ----------------- | ------------------- | ------- | ----------------------------------- | ---------------------------------- |
| `ryzen-9950x3d`   | Zen 5 9950X3D       | x86_64  | CachyOS-LTO                         | VFIO-ready, Lanzaboote secure boot |
| `macbook-pro-9-2` | Ivy Bridge i5-3210M | x86_64  | xanmod + CachyOS-LTO specialisation | Apple hardware drivers             |
| `pixel-9-pro`     | Tensor G4           | aarch64 | AVF (crosvm)                        | Android VM, remote builder         |

## Commands

```bash
nrb                    # Build + switch current host
nrb --update           # Update flake inputs + build + switch
nrb --dry              # Build + show diff, don't activate
nrb --check            # Evaluate all configs without building (~10s)
nix flake check        # Full suite including VM tests
nix build .#docs       # Build documentation site
```

## Documentation

| Document                                       | Scope                                      |
| ---------------------------------------------- | ------------------------------------------ |
| [`docs/USAGE.md`](docs/USAGE.md)               | Importing modules in your flake            |
| [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md)   | Commands, formatters, hooks, checks, tests |
| [`docs/STYLE.md`](docs/STYLE.md)               | Code standards + option conventions        |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Directory layout + module boundaries       |
| [`docs/INSTALLATION.md`](docs/INSTALLATION.md) | BTRFS + LUKS + disko install               |
| [`docs/SECURE-BOOT.md`](docs/SECURE-BOOT.md)   | Lanzaboote enrollment                      |
| [`docs/SECRETS.md`](docs/SECRETS.md)           | agenix secrets management                  |
| [`docs/NETWORKING.md`](docs/NETWORKING.md)     | DNS, Portmaster, Mullvad                   |

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

[MIT](LICENSE)

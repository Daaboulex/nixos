# Using These Modules in Your Flake

This flake exports reusable NixOS and Home Manager modules under the `myModules.*` option namespace.

## Add the Flake Input

```nix
{
  inputs.fahlke-nix.url = "github:Daaboulex/nixos";
}
```

## Import a NixOS Module

Each NixOS module is exported as `modules.nixos.<scope>-<name>`. Import specific modules — there is no `default` (76+ modules, no sensible single import).

```nix
{
  inputs,
  ...
}:
{
  imports = [
    inputs.fahlke-nix.modules.nixos.hardware-pipewire
    inputs.fahlke-nix.modules.nixos.security-hardening
    inputs.fahlke-nix.modules.nixos.services-earlyoom
  ];

  myModules.hardware.pipewire.enable = true;
  myModules.security.hardening.enable = true;
  myModules.services.earlyoom.enable = true;
}
```

## Import a Home Manager Module

Home Manager modules are exported as `homeModules.<name>` (also accessible via `modules.homeManager.<name>`). They require `myLib` in `extraSpecialArgs`:

```nix
{
  home-manager.extraSpecialArgs = {
    myLib = inputs.fahlke-nix.lib;
  };
  home-manager.sharedModules = [
    inputs.fahlke-nix.homeModules.git
    inputs.fahlke-nix.homeModules.zsh
  ];
}
```

Then in your Home Manager config:

```nix
{
  myModules.home.git.enable = true;
  myModules.home.zsh.enable = true;
}
```

## Library Helpers

Six helper functions exported as `lib.*`:

| Helper             | Type        | Purpose                             |
| ------------------ | ----------- | ----------------------------------- |
| `mkSimplePackage`  | Factory     | Wrap a single binary into a package |
| `themeCtx`         | Factory     | Build theme context for HM modules  |
| `withStdenvCC`     | Factory     | Override stdenv compiler            |
| `cap`              | Pre-applied | Capability detection                |
| `mkSettingsOption` | Pre-applied | Declare a freeform settings option  |
| `mergeSettings`    | Pre-applied | Deep-merge settings attrsets        |

Usage: `inputs.fahlke-nix.lib.<helper>`.

## Module Naming Convention

NixOS modules follow a mechanism-first taxonomy:

| Category     | Examples                                                      |
| ------------ | ------------------------------------------------------------- |
| `boot-*`     | `boot-loader`, `boot-kernel`, `boot-hibernate`                |
| `hardware-*` | `hardware-pipewire`, `hardware-gpu-amd`, `hardware-hid-apple` |
| `services-*` | `services-earlyoom`, `services-syncthing`, `services-mullvad` |
| `security-*` | `security-hardening`, `security-ssh`, `security-agenix`       |
| `desktop-*`  | `desktop-plasma`, `desktop-displays`                          |
| `gaming-*`   | `gaming-steam`, `gaming-gamemode`                             |

Full module list: `nix flake show github:Daaboulex/nixos`

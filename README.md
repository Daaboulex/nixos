# NixOS Flake Configuration

Modular NixOS flake configuration built on [flake-parts](https://github.com/hercules-ci/flake-parts) with a custom `myModules.*` option namespace for toggling features declaratively.

## Design Philosophy

- **Dendritic modularity** — every feature is an independent, toggleable module behind `myModules.*`. No monolithic configs. Modules work in isolation and compose freely.
- **Bleeding-edge** — tracks `nixos-unstable`, CachyOS kernels with LTO, and latest upstream flake inputs.
- **Performance-first** — microarchitecture-specific compilation, BORE scheduler, ananicy-cpp, sysctl tuning, THP, hardware-specific governors.
- **Best practices** — flake-parts composition, sops-nix secrets, Lanzaboote Secure Boot, hardened SSH, proper NixOS module patterns.
- **Reproducible state** — opt-in impermanence erases root on every boot; only explicitly declared system state survives.

## Quick Start

### Build & Switch

```bash
nrb                    # Build + switch (activates immediately)
nrb --update           # Update flake inputs + build + switch
nrb --dry              # Build + show diff, don't activate
nrb --boot             # Build + activate on next reboot
nrb --trace            # Build with --show-trace (debugging)
nrb --check            # Evaluate ALL configs without building (fast sanity check)
nrb --host <name>      # Build a specific nixosConfiguration
nrb --list             # Show all configurations + specialisations
nrb --update --dry     # Update inputs + build + diff only
```

`nrb` builds **only the current hostname** by default (detected via `hostname`). Hosts with specialisations (e.g., MacBook kernel variants) build all variants in a single `nrb` — they appear as separate boot entries in systemd-boot. After build, `nrb` shows all specialisations with their kernel versions.

Features: build timing, kernel change detection, specialisation listing, `nvd` system diff, Home Manager generation diff, generation display, rollback hint, auto-regenerates `docs/OPTIONS.md` on successful switch.

```bash
nrb-check              # Evaluate ALL configs + specialisations (standalone, auto-discovers hosts)
nrb-info               # System state, active specialisation, store size, generations
```

### Shell Aliases & Tools

| Alias/Tool | Description |
|------------|-------------|
| `gc` | Collect garbage (system + user + HM generations) + optimize store |
| `lc` | Clear system logs (dmesg, journald, /var/log) |
| `cat` | `bat --paging=never` (syntax-highlighted) |
| `z <dir>` | zoxide smart cd (learns frequent dirs) |
| `Ctrl+R` | fzf fuzzy history search |
| `Ctrl+T` | fzf fuzzy file search |
| `Alt+C` | fzf fuzzy directory cd |

Shell tools are individual home modules in `home/modules/`: starship, zoxide, fzf, direnv + nix-direnv, bat.

## Architecture

### Directory Layout

```
flake.nix                              # Entry point — delegates to parts/
parts/
├── flake-module.nix                   # Central import hub for all modules + hosts
├── overlays.nix                       # Custom package overlays
├── treefmt.nix                        # Unified code formatting (nixfmt, shfmt, etc.)
├── git-hooks.nix                      # Pre-commit hooks (formatting, linting)
├── tests.nix                          # NixOS VM integration tests
├── system/                            # System-level NixOS modules
│   ├── boot.nix                       # Bootloader, Secure Boot (Lanzaboote), Plymouth
│   ├── kernel.nix                     # Kernel variant selection + CachyOS tuning
│   ├── nix.nix                        # Nix daemon, caches, GC settings
│   ├── users.nix                      # User/group management, primaryUser option
│   ├── security.nix                   # Hardened kernel params, PAM limits
│   ├── ssh.nix                        # SSH server + fail2ban
│   ├── sops.nix                       # Secrets management (sops-nix)
│   ├── services.nix                   # System services (CUPS, fstrim, earlyoom, etc.)
│   ├── packages.nix                   # System-wide packages by category
│   ├── filesystems.nix                # Filesystem support (Linux, Windows, Mac, etc.)
│   ├── impermanence.nix              # Opt-in ephemeral root (BTRFS rollback)
│   └── cachyos-settings.nix           # CachyOS system tuning (journald, sysctl, THP)
├── hardware/                          # Hardware-specific modules
│   ├── core.nix                       # Firmware, fwupd, common sensors
│   ├── cpu-amd.nix                    # AMD CPU (P-State, Prefcore, 3D V-Cache, KVM)
│   ├── cpu-intel.nix                  # Intel CPU (P-State, EPP, KVM, thermald)
│   ├── gpu-amd.nix                    # AMD GPU (amdgpu, mesa, RADV, DRM params)
│   ├── gpu-intel.nix                  # Intel GPU (i915, media acceleration)
│   ├── gpu-nvidia.nix                 # NVIDIA GPU (proprietary driver, CUDA, Optimus)
│   ├── graphics.nix                   # Graphics abstraction (OpenGL, Vulkan, 32-bit)
│   ├── audio.nix                      # PipeWire / PulseAudio configuration
│   ├── networking.nix                 # Network drivers, DNS, firewall
│   ├── bluetooth.nix                  # Bluetooth daemon + profiles
│   ├── performance.nix                # CPU governor, ananicy-cpp, IRQ balance, scx
│   ├── power.nix                      # TLP power management (laptop + desktop)
│   ├── goxlr.nix                      # GoXLR audio interface (EQ, denoise, profiles)
│   ├── piper.nix                      # Piper mouse configuration GUI
│   ├── streamcontroller.nix           # Stream Deck integration
│   ├── macbook/                       # MacBook-specific hardware
│   │   ├── default.nix                # Fan control, touchpad, keyboard config
│   │   ├── applesmc-comprehensive-fixes.patch  # AppleSMC race + null fixes
│   │   └── at24-suppress-regulator-warning.patch  # EEPROM regulator fix
│   └── yeetmouse/                     # Custom mouse acceleration driver
│       ├── default.nix                # Build overlay (LLVM detection, patches)
│       ├── driver.nix                 # Kernel module + sysfs parameter definitions
│       ├── package.nix                # Package derivation
│       └── devices/g502.nix           # Logitech G502 device-specific config + udev
├── desktop/                           # Desktop environment modules
│   ├── kde.nix                        # KDE Plasma 6, SDDM, XKB, portals
│   ├── displays.nix                   # Multi-monitor config (SDDM output, rotation)
│   └── flatpak.nix                    # Flatpak runtime + app management
├── apps/                              # Application modules
│   ├── gaming.nix                     # Steam, Proton, emulators, gamemode
│   ├── wine.nix                       # Wine + Bottles
│   ├── tools/                         # Helper scripts (sysdiag, iommu, dev tools)
│   ├── arkenfox.nix                   # Firefox/LibreWolf security hardening
│   ├── portmaster.nix                 # Portmaster network firewall
│   └── tidalcycles.nix                # Live coding music environment
└── hosts/
    ├── ryzen-9950x3d/                 # Desktop host (Zen 5, RDNA 4, CachyOS-LTO)
    │   ├── flake-module.nix           # nixosConfiguration + module imports + overlays
    │   ├── default.nix                # Host-specific myModules.* option values
    │   ├── hardware-configuration.nix # Auto-generated (BTRFS + LUKS layout)
    │   └── disko.nix                  # Declarative disk partitioning layout
    └── macbook-pro-9-2/               # Laptop host (Ivy Bridge, Intel HD4000)
        ├── flake-module.nix           # Single config + xanmod/cachyos specialisations
        ├── default.nix                # MacBook-specific tuning + hardware fixes
        ├── hardware-configuration.nix # Auto-generated
        └── disko.nix                  # Declarative disk partitioning layout
home/
├── home.nix                           # Home Manager entry point (auto-discovers modules)
├── modules/                           # Home Manager modules (auto-discovered)
│   ├── base/default.nix               # Base user config (home directory, env)
│   ├── git/default.nix                # Git configuration
│   ├── zsh/default.nix                # Zsh shell config + nrb rebuild helper
│   ├── starship/default.nix           # Starship shell prompt
│   ├── zoxide/default.nix             # Zoxide smart cd
│   ├── fzf/default.nix                # fzf fuzzy finder
│   ├── direnv/default.nix             # direnv + nix-direnv
│   ├── bat/default.nix                # bat syntax-highlighted cat
│   ├── plasma/default.nix             # KDE Plasma settings, KWin scripts, tiling
│   ├── konsole/default.nix            # Konsole terminal emulator
│   ├── kate/default.nix               # Kate text editor
│   ├── okular/default.nix             # Okular PDF viewer
│   ├── elisa/default.nix              # Elisa music player (disabled)
│   ├── ghostwriter/default.nix        # Ghostwriter markdown editor (disabled)
│   ├── vscode/default.nix             # VS Code extensions + settings
│   ├── gtk/default.nix                # GTK theme + cursor + icons
│   ├── btop/default.nix               # btop system monitor
│   ├── htop/default.nix               # htop system monitor
│   ├── xdg/default.nix                # XDG MIME types + desktop integration
│   ├── flatpak/default.nix            # Flatpak app declarations + theme overrides
│   └── displays/default.nix           # Display arrangement + toggle + tiling scripts
├── hosts/
│   ├── ryzen-9950x3d/default.nix      # Host-specific HM overrides
│   └── macbook-pro-9-2/default.nix    # MacBook HM overrides (single GPU, etc.)
scripts/
├── install-btrfs.sh                   # Automated BTRFS+LUKS install script
├── generate-docs.nix                  # Auto-generates docs/OPTIONS.md
├── test-shell-functions.sh            # Validate all configs, flags, functions, and docs
└── update-docs.sh                     # Wrapper to run doc generation
docs/
├── OPTIONS.md                         # Auto-generated module option reference
├── installation.md                    # Step-by-step installation tutorial
└── secure-boot.md                     # Secure Boot setup & recovery guide
secrets/
└── secrets.yaml                       # Encrypted secrets (sops-nix)
.claude/commands/                      # Claude Code slash commands (build, check, fmt, etc.)
```

### Module System

Every custom NixOS module follows this pattern:

```nix
{ inputs, ... }: {
  flake.nixosModules.<scope>-<name> = { config, lib, pkgs, ... }:
    let cfg = config.myModules.<scope>.<feature>;
    in {
      _class = "nixos";
      options.myModules.<scope>.<feature> = {
        enable = lib.mkEnableOption "Feature description";
        # feature-specific options with lib.mkOption
      };
      config = lib.mkIf cfg.enable {
        # NixOS configuration applied when enabled
      };
    };
}
```

Modules are exported as `flake.nixosModules.<scope>-<feature>` (e.g., `hardware-gpu-amd`, `system-boot`). Hosts import only the modules they need.

### Host Composition

Each host's `flake-module.nix` defines one or more `nixosConfiguration` entries that:
1. Import the needed `nixosModules` from the flake
2. Import external modules (Home Manager, Lanzaboote, sops-nix, etc.)
3. Stack overlays for external packages
4. The host's `default.nix` then enables and configures `myModules.*` options

Current hosts:
- **ryzen-9950x3d** — Desktop (Zen 5, RDNA 4, 64GB, CachyOS-LTO kernel, multi-monitor)
- **macbook-pro-9-2** — Laptop (Ivy Bridge i5, Intel HD4000, 16GB, default kernel + xanmod/cachyos specialisations)

### Kernel Variant Specialisations

The MacBook host uses NixOS **specialisations** to provide multiple kernel variants in a single build. Each specialisation creates a separate boot entry in systemd-boot:

| Boot Entry | Kernel | MacBook Patches | Description |
|-----------|--------|-----------------|-------------|
| NixOS (default) | Standard NixOS | Enabled | Safe, stable baseline |
| NixOS (xanmod) | Xanmod | Disabled | Better latency, newer patches |
| NixOS (cachyos) | CachyOS (BORE, 1000Hz, full preempt) | Disabled | Full CachyOS optimizations |

One `nrb` builds all 3 variants. If the active kernel breaks, select another from the boot menu — no need to rebuild. This is safer than separate `nixosConfigurations` because all variants are guaranteed to be built and available.

### Home Manager Integration

Home Manager runs as a NixOS module (not standalone). User modules in `home/modules/` are auto-discovered via `home/modules/default.nix`. Host-specific overrides go in `home/hosts/<hostname>/default.nix`.

Home Manager modules can read NixOS options via `osConfig` (e.g., `osConfig.time.timeZone`). The primary username is derived from `config.myModules.primaryUser` (set in `parts/system/users.nix`, defaults to `"user"`).

### Overlay System

External packages enter via overlays stacked in the host's `flake-module.nix`. Current overlays:

| Overlay | Source |
|---------|--------|
| `self.overlays.default` | Custom overlays from `parts/overlays.nix` (reshade-shaders) |
| `nix-cachyos-kernel.overlays.pinned` | CachyOS kernel packages |
| `tidalcycles.overlays.default` | TidalCycles music packages |
| `antigravity.overlays.default` | Antigravity IDE |
| `nx-save-sync.overlays.default` | Switch save sync |
| `portmaster.overlays.default` | Portmaster firewall |
| `occt-nix.overlays.default` | OCCT benchmark |
| `claude-code.overlays.default` | Claude Code AI assistant |
| `lsfg-vk.overlays.default` | Vulkan frame generation |
| `vkbasalt-overlay.overlays.default` | vkBasalt overlay (Vulkan post-processing with in-game UI) |
| `mesa-git-nix.overlays.default` | Bleeding-edge Mesa builds |

To add a new overlay: add the flake input in `flake.nix`, then add `inputs.<name>.overlays.default` to the host's overlay list.

## Custom Packages & Patches

This flake includes several custom-built packages, driver patches, and scripts that go beyond standard NixOS configuration.

### YeetMouse Driver (`parts/hardware/yeetmouse/`)

Custom mouse acceleration driver with 8 acceleration modes (linear, power, classic, motivity, synchronous, natural, jump, LUT). Includes:

- **LLVM/Clang build detection** — automatically detects CachyOS LLVM kernels and uses `clang`/`ld.lld` for module compilation
- **Kernel patches** — converts `printk()` calls to proper `KERN_INFO`/`KERN_ERR` levels
- **GUI patches** — fixes hardcoded exponent slider limits (allows 0.00 for Jump mode), hides unnecessary root privilege warning
- **Upstream parameter application** — the `driver.nix` module writes acceleration settings to sysfs via udev on any HID mouse connect. Configure parameters through `hardware.yeetmouse` options (sensitivity, mode, rotation, etc.)
- **G502 device module** — libinput HWDB entries force flat acceleration profile for wired (`c08d`) and Lightspeed wireless (`c539`) variants. This prevents libinput from applying additional acceleration on top of YeetMouse's custom curve. DPI and polling rate are configurable.

Options: `hardware.yeetmouse` (acceleration parameters), `myModules.hardware.yeetmouse.devices.g502` (HWDB flat profile, product IDs, DPI).

### Mesa-Git (`parts/hardware/graphics.nix`)

Bleeding-edge Mesa builds from git main (critical for RDNA 4 optimizations). Features:

- **Vendor-specific compilation** — optionally build only AMD, Intel, or NVIDIA drivers to reduce build time
- **32-bit support** — separate `mkMesaGit32` for Steam/Wine compatibility
- **Automatic fallback** — standard Mesa used when `mesaGit.enable = false`

Options: `myModules.hardware.graphics.mesaGit.enable`, `mesaGit.drivers = [ "amd" ]`.

### GoXLR Audio Interface (`parts/hardware/goxlr.nix`)

Full GoXLR Mini/Full support with:

- **ALSA UCM patch** — fixes GoXLR Mini HiFi channel count (`HWChannels 23` -> `21`)
- **PipeWire parametric EQ** — per-channel filter-chain modules (System, Game, Chat, Music, Sample) with DT990 Pro preset
- **DeepFilterNet3 neural denoise** — two-stage chain: 120Hz highpass filter + DeepFilterNet3 LADSPA neural noise suppression on chat mic. Configurable attenuation limits, ERB/DF thresholds, processing buffers.
- **Profile toggle script** — `goxlr-toggle` switches between Active and Sleep profiles for both device and microphone via `goxlr-client`

Options: `myModules.audio.goxlr.enable`, `eq.enable`, `denoise.enable`, `toggle.enable`, per-channel sink overrides, EQ presets.

### StreamController Patch (`parts/hardware/streamcontroller.nix`)

Patches StreamController (Elgato Stream Deck app) to add USB websocket support and fix Elgato USB vendor ID resolution.

### KWin Scripts (`home/modules/plasma/default.nix`)

Two custom KWin scripts built as derivations:

- **late-tile** — watches for windows whose `WM_CLASS` changes after initial mapping (Electron, Flatpak apps) and retiles them once the class stabilizes. Without this, these apps get placed as floating windows instead of tiling.
- **Fluid Tile v7** — auto-tiling KWin script (from Codeberg) with extensive configuration: blocklist for apps that break when tiled, tile priority, overflow handling, layout cycling, dynamic desktop management.

### Display Management (`home/modules/displays/default.nix`)

Auto-generated scripts from `myModules.desktop.displays` monitor definitions:

- **`display-arrange`** — kscreen-doctor commands to set resolution, refresh rate, position, rotation, and VRR for each monitor. Runs at login and after sleep/wake.
- **Per-monitor toggle scripts** (e.g., `crt-toggle`) — enable/disable monitors with KWin D-Bus window migration (moves windows off the screen before disabling), repositions other monitors, reconfigures KWin.
- **Tiling activation** — writes per-monitor tile layouts to KWin config (using monitor UUIDs), purges stale/phantom entries.
- **systemd user services** — `display-arrange` (login), `display-arrange-wake` (post-sleep with output detection delay).

### Custom Scripts (`parts/apps/tools/`)

- **sysdiag** (585 lines) — comprehensive NixOS system diagnostics: CPU, GPU, memory, storage, network, services, kernel, scheduler, display, errors. Auto-detects AMD/Intel/NVIDIA hardware and shows hardware-specific metrics (P-State, GPU clocks, NVMe temps, scx status).
- **list-iommu-groups** — lists IOMMU groups for GPU passthrough planning.


### Arkenfox Auto-Update (`parts/apps/arkenfox.nix`)

Systemd service + timer that downloads the latest Arkenfox `user.js` Firefox security hardening config. Runs daily with retry on failure. Supports Flatpak Firefox/LibreWolf profiles.

### Gaming Stack (`parts/apps/gaming.nix`, `parts/overlays.nix`)

Integrated gaming performance and visual enhancement stack:

- **GameMode** — per-game performance daemon: renices to -10, sets AMD GPU to high performance, integrates with ananicy-cpp and scx_lavd without conflicts
- **vkBasalt Overlay** — Vulkan post-processing layer with in-game ImGui UI for real-time effect tuning (Wayland + X11). Fork of [vkBasalt overlay](https://github.com/Boux/vkBasalt_overlay) with full Wayland input support. Ships with ReShade shaders (Vibrance.fx, LiftGammaGain.fx, Tonemap.fx, Curves.fx, etc.). Configurable via `myModules.gaming.vkbasalt` options (effects, casSharpness, overlayKey, toggleKey, extraConfig)
- **MangoHud + MangoJuice** — FPS/GPU/CPU overlay (MangoHud) with a GUI configurator (MangoJuice)
- **Steam** — with Proton-GE, Gamescope session support, and steam-devices udev rules
- **Emulators** — Ryubing (Switch), Eden (Switch community fork), Azahar (3DS), Prism Launcher (Minecraft)

#### vkBasalt Overlay Usage

vkBasalt is off by default (`ENABLE_VKBASALT=0`). Enable per-game via Steam launch options or the `vkbasalt-run` wrapper:

```bash
# Steam → Game Properties → Launch Options:
ENABLE_VKBASALT=1 gamemoderun %command%    # Enable vkBasalt
vkbasalt-run gamemoderun %command%          # Same, using wrapper
```

**In-game controls:**
- **F1** — open the overlay UI (add/remove effects, adjust parameters, save/load configs)
- **Home** — toggle all effects on/off

All effect parameters (Vibrance, CAS sharpness, LiftGammaGain, etc.) can be adjusted live through the overlay UI without restarting the game. Per-game configs are saved/loaded from `~/.config/vkBasalt-overlay/configs/`.

vkBasalt is a standard Vulkan layer (same mechanism as validation layers). It does NOT inject into game processes or modify game memory — it applies effects after the game renders each frame, like a monitor's built-in color settings. No anti-cheat (EAC, BattlEye, VAC) flags Vulkan layers.

#### Performance Stack (no conflicts)

| Layer | What it does | Priority interaction |
|-------|-------------|---------------------|
| **ananicy-cpp** | Sets Game processes to nice=-5 | Only applies if current nice is worse |
| **gamemode** | Sets gamemoderun'd processes to nice=-10 | Direct setpriority, ananicy won't override |
| **scx_lavd** | BPF CPU scheduler, reads nice values | Never sets nice, only uses them for scheduling |

Options: `myModules.gaming.*` — see [docs/OPTIONS.md](docs/OPTIONS.md) for all gaming options.

## Module Reference

### System Modules

| Module | Option Prefix | Description |
|--------|--------------|-------------|
| `system-boot` | `myModules.system.boot` | Bootloader (systemd-boot/GRUB), Secure Boot, Plymouth |
| `system-kernel` | `myModules.kernel` | Kernel variant, CachyOS tuning, microarch, extra params |
| `system-nix` | `myModules.system.nix` | Nix daemon, binary caches, build settings |
| `system-users` | `myModules.system.users` | User accounts, groups, `primaryUser` option |
| `system-security` | `myModules.security.system` | Kernel hardening, PAM limits |
| `system-ssh` | `myModules.security.ssh` | SSH server, hardened ciphers, fail2ban |
| `system-sops` | `myModules.security.sops` | sops-nix secrets management |
| `system-services` | `myModules.system.services` | CUPS, fstrim, earlyoom, ACPI, UPower, GeoClue |
| `system-packages` | `myModules.system.packages` | System packages by category |
| `system-filesystems` | `myModules.system.filesystems` | Filesystem kernel modules + userspace tools |
| `system-impermanence` | `myModules.system.impermanence` | Opt-in ephemeral root (BTRFS rollback, persist declarations) |
| `cachyos-settings` | `myModules.cachyos.settings` | CachyOS sysctl tuning, journald, THP |

### Hardware Modules

| Module | Option Prefix | Description |
|--------|--------------|-------------|
| `hardware-core` | `myModules.hardware.core` | Firmware, fwupd, drive temp sensors |
| `hardware-cpu-amd` | `myModules.hardware.cpu.amd` | AMD P-State, Prefcore, 3D V-Cache, KVM, microcode |
| `hardware-cpu-intel` | `myModules.hardware.cpu.intel` | Intel P-State, EPP, KVM, thermald, microcode |
| `hardware-gpu-amd` | `myModules.hardware.graphics.amd` | AMDGPU driver, DRM params, RDNA 4 fixes |
| `hardware-gpu-intel` | `myModules.hardware.graphics.intel` | i915 driver, media acceleration |
| `hardware-gpu-nvidia` | `myModules.hardware.graphics.nvidia` | NVIDIA proprietary driver, CUDA, Optimus |
| `hardware-graphics` | `myModules.hardware.graphics` | OpenGL, Vulkan, 32-bit, mesa-git vendor selection |
| `hardware-audio` | `myModules.hardware.audio` | PipeWire, ALSA, low-latency config |
| `hardware-networking` | `myModules.hardware.networking` | Network drivers, DNS nameservers, firewall |
| `hardware-bluetooth` | `myModules.hardware.bluetooth` | Bluetooth daemon and profiles |
| `hardware-performance` | `myModules.hardware.performance` | CPU governor, ananicy-cpp, IRQ balance, scx schedulers |
| `hardware-power` | `myModules.hardware.power` | TLP power management |
| `hardware-goxlr` | `myModules.audio.goxlr` | GoXLR audio (UCM patch, EQ, denoise, toggle) |
| `hardware-piper` | `myModules.hardware.piper` | Gaming mouse configuration |
| `hardware-streamcontroller` | `myModules.hardware.streamcontroller` | Stream Deck (patched for USB websockets) |
| `hardware-macbook` | `myModules.hardware.macbook` | MacBook fan (mbpfan), touchpad, keyboard, kernel patches |
| `hardware-yeetmouse` | `myModules.hardware.yeetmouse` | Mouse acceleration driver (8 modes, LLVM build) |

### Desktop Modules

| Module | Option Prefix | Description |
|--------|--------------|-------------|
| `desktop-kde` | `myModules.desktop.kde` | KDE Plasma 6, SDDM, XKB layout, KDE Connect |
| `desktop-displays` | `myModules.desktop.displays` | Multi-monitor (SDDM config, rotation, toggle scripts) |
| `desktop-flatpak` | `myModules.desktop.flatpak` | Flatpak runtime and portals |

### App Modules

| Module | Option Prefix | Description |
|--------|--------------|-------------|
| `apps-gaming` | `myModules.gaming` | Steam, Proton, GameMode, vkBasalt overlay, MangoHud/MangoJuice, emulators, RADV tuning |
| `apps-wine` | `myModules.programs.wine` | Wine variants + Bottles |
| `tools-sysdiag` | `myModules.tools.sysdiag` | Comprehensive NixOS system diagnostics |
| `tools-iommu` | `myModules.tools.iommu` | IOMMU group listing |

| `apps-development` | `myModules.development` | Build tools, Claude Code, Saleae Logic |
| `apps-arkenfox` | `myModules.security.arkenfox` | Arkenfox auto-download + Flatpak Firefox support |
| `apps-portmaster` | `myModules.security.portmaster` | Portmaster firewall + system tray notifier |
| `apps-tidalcycles` | `myModules.music.tidalcycles` | TidalCycles live coding + SuperDirt |

### Home Manager Modules

| Module | Description |
|--------|-------------|
| `base` | Base user config, home directory, state version |
| `git` | Git config, GitHub CLI (credentials set per-host) |
| `zsh` | Zsh shell config + `nrb` rebuild helper |
| `starship` | Starship shell prompt |
| `zoxide` | Zoxide smart cd |
| `fzf` | fzf fuzzy finder |
| `direnv` | direnv + nix-direnv |
| `bat` | bat syntax-highlighted cat |
| `plasma` | KDE Plasma settings, late-tile + Fluid Tile KWin scripts, shortcuts, night light |
| `konsole` | Konsole terminal emulator |
| `kate` | Kate text editor |
| `okular` | Okular PDF viewer |
| `elisa` | Elisa music player (disabled) |
| `ghostwriter` | Ghostwriter markdown editor (disabled) |
| `vscode` | VSCodium + extensions (Nix IDE, Catppuccin) |
| `gtk` | Breeze Dark theme, icons, cursors |
| `btop` | btop monitor (Tokyo Night theme, GPU layout per-host, AMD ROCm GPU detection) |
| `htop` | htop config |
| `xdg` | XDG user directories |
| `flatpak` | Flatpak apps + Wayland/theme overrides |
| `displays` | display-arrange, toggle scripts, tiling activation, wake service |

For full option details with types and defaults, see [docs/OPTIONS.md](docs/OPTIONS.md) (auto-generated, 200+ options across 13 categories).

## Installing on a New System

### Prerequisites

- [NixOS unstable graphical ISO](https://channels.nixos.org/nixos-unstable/latest-nixos-graphical-x86_64-linux.iso) booted on the target machine (UEFI mode)
- Network connectivity
- This repository cloned or accessible on the live USB

### Automated Install (Recommended)

The `scripts/install-btrfs.sh` script handles partitioning, encryption, BTRFS subvolumes, hardware config generation, and NixOS installation:

```bash
# Clone the repo on the live USB
git clone <repo-url> ~/nix && cd ~/nix

# Run the installer (shows all disks, requires multiple confirmations)
sudo bash scripts/install-btrfs.sh /dev/sdX <hostname>

# With options:
sudo bash scripts/install-btrfs.sh --swap 4G /dev/sdX <hostname>          # Add swap
sudo bash scripts/install-btrfs.sh --no-encrypt /dev/sdX <hostname>       # No LUKS
sudo bash scripts/install-btrfs.sh --no-install /dev/sdX <hostname>       # Partition only
sudo bash scripts/install-btrfs.sh --swap 2048M /dev/nvme0n1 <hostname>   # NVMe + swap in MiB
```

Safety features:
- Shows **all disks** with model, serial, size, and current contents
- Requires typing the **full device path** to confirm
- Requires typing `ERASE` if the disk has existing OS partitions
- Warns if not booted in UEFI mode
- Warns if disk is < 20 GB
- Resolves `/dev/disk/by-id/*` symlinks automatically
- Cleanup trap on failure (unmounts, closes LUKS)
- Auto-enables Nix experimental features (flakes work on fresh live USB)

Creates: GPT + 512M ESP + optional swap + BTRFS with subvolumes (@, @home, @nix, @log, @cache, @tmp, @snapshots). SSD auto-detection adds `ssd,discard=async` mount options.

For a complete walkthrough including WiFi setup, post-install configuration, troubleshooting, and partition layout diagrams, see [docs/installation.md](docs/installation.md).

### Declarative Install with Disko

Each host includes a `disko.nix` declarative disk layout that mirrors the BTRFS + LUKS subvolume structure. For new installations:

```bash
# From a NixOS live USB with flakes enabled
sudo nix run github:nix-community/disko -- --mode disko parts/hosts/<hostname>/disko.nix
sudo nixos-install --flake .#<hostname>
```

Disko manages the NixOS root disk (ESP + LUKS + BTRFS subvolumes). Additional data drives (NTFS, ext4) remain in `hardware-configuration.nix`.

### Manual Install

<details>
<summary>Step-by-step manual instructions (click to expand)</summary>

#### Partition & Format (BTRFS + LUKS)

```bash
# Enable flakes on live USB
export NIX_CONFIG="experimental-features = nix-command flakes"

# Identify your disk
lsblk

# Partition (GPT: 512MB EFI + rest for LUKS)
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 512MiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary 512MiB 100%

# Encrypt root partition
cryptsetup luksFormat --type luks2 /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptroot

# Format
mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1
mkfs.btrfs -L nixos /dev/mapper/cryptroot
```

#### Create BTRFS Subvolumes

```bash
mount /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@snapshots
umount /mnt

# Mount subvolumes (add ssd,discard=async for SSDs)
mount -o subvol=@,compress=zstd,noatime /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{home,nix,var/log,var/cache,tmp,boot,.snapshots}
mount -o subvol=@home,compress=zstd,noatime /dev/mapper/cryptroot /mnt/home
mount -o subvol=@nix,compress=zstd,noatime /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@log,compress=zstd,noatime /dev/mapper/cryptroot /mnt/var/log
mount -o subvol=@cache,compress=zstd,noatime /dev/mapper/cryptroot /mnt/var/cache
mount -o subvol=@tmp,compress=zstd,noatime /dev/mapper/cryptroot /mnt/tmp
mount -o subvol=@snapshots,compress=zstd,noatime /dev/mapper/cryptroot /mnt/.snapshots
mount /dev/nvme0n1p1 /mnt/boot
```

#### Generate Hardware Configuration

```bash
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix parts/hosts/<hostname>/hardware-configuration.nix
```

</details>

### Clone & Configure

```bash
# Clone the flake (into the new system or on another machine)
git clone <repo-url> /mnt/home/<user>/Documents/nix
cd /mnt/home/<user>/Documents/nix

# Copy hardware config (skip if using install-btrfs.sh — it does this automatically)
cp /mnt/etc/nixos/hardware-configuration.nix parts/hosts/<hostname>/hardware-configuration.nix
```

### Step 5: Create Host Configuration

Create `parts/hosts/<hostname>/` with three files:

**`hardware-configuration.nix`** — from Step 3.

**`flake-module.nix`** — defines `nixosConfigurations.<hostname>`, imports modules your hardware needs:

```nix
{ inputs, ... }: {
  flake.nixosConfigurations.<hostname> = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      ./default.nix
      ({ config, ... }: {
        imports = [
          # System (always needed)
          inputs.self.nixosModules.system-boot
          inputs.self.nixosModules.system-kernel
          inputs.self.nixosModules.system-nix
          inputs.self.nixosModules.system-users
          inputs.self.nixosModules.system-security
          inputs.self.nixosModules.system-filesystems
          inputs.self.nixosModules.system-ssh
          inputs.self.nixosModules.system-services
          inputs.self.nixosModules.system-packages

          # Hardware (pick for your system)
          inputs.self.nixosModules.hardware-core
          inputs.self.nixosModules.hardware-cpu-amd     # or cpu-intel
          inputs.self.nixosModules.hardware-gpu-amd     # or gpu-intel / gpu-nvidia
          inputs.self.nixosModules.hardware-graphics
          inputs.self.nixosModules.hardware-audio
          inputs.self.nixosModules.hardware-networking
          inputs.self.nixosModules.hardware-performance
          inputs.self.nixosModules.hardware-power

          # Desktop
          inputs.self.nixosModules.desktop-kde
          inputs.self.nixosModules.desktop-flatpak

          # Apps (optional)
          inputs.self.nixosModules.apps-gaming
          inputs.self.nixosModules.tools-sysdiag
          inputs.self.nixosModules.tools-iommu
          inputs.self.nixosModules.apps-development
          # ... add more as needed
        ];
      })
      ../../../home/home.nix
      inputs.home-manager.nixosModules.home-manager
      inputs.nix-flatpak.nixosModules.nix-flatpak
      inputs.lanzaboote.nixosModules.lanzaboote
      inputs.sops-nix.nixosModules.sops
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { inherit inputs; };
        nixpkgs.config.allowUnfree = true;
        nixpkgs.overlays = [
          inputs.self.overlays.default
          # Add overlays needed for your modules:
          # inputs.nix-cachyos-kernel.overlays.pinned  # if using CachyOS kernel
          # inputs.portmaster.overlays.default          # if using Portmaster
        ];
      }
    ];
  };
}
```

**`default.nix`** — enable and configure modules for this host:

```nix
{ config, pkgs, inputs, lib, ... }: {
  imports = [ ./hardware-configuration.nix ];

  myModules = {
    system = {
      nix.enable = true;
      users.enable = true;
      services.enable = true;
      filesystems = { enable = true; enableAll = true; };
      packages = { base = true; dev = true; editors = true; };
      boot = { enable = true; loader = "systemd-boot"; };
    };
    hardware = {
      core.enable = true;
      networking.enable = true;
      audio.enable = true;
      cpu.amd.enable = true;       # or cpu.intel
      graphics = {
        enable = true;
        amd.enable = true;         # or intel / nvidia
      };
      performance.enable = true;
      power.enable = true;
    };
    desktop.kde.enable = true;
    kernel = { enable = true; variant = "default"; };
    security.system.enable = true;
  };

  # Required host-specific settings
  networking.hostName = "<hostname>";
  system.stateVersion = "26.05";   # Set to your NixOS version
  time.timeZone = "Europe/Berlin"; # Your timezone
  i18n.defaultLocale = "en_US.UTF-8";
}
```

### Step 6: Create Home Manager Host Config

Create `home/hosts/<hostname>/default.nix`:

```nix
{ config, lib, ... }: {
  # Git credentials
  programs.git.settings.user = {
    name = "Your Name";
    email = "your@email.com";
  };

  # Flatpak packages for this host
  services.flatpak.packages = [
    "com.spotify.Client"
    # ... add apps
  ];
}
```

### Step 7: Register & Install

```bash
# Add host import to parts/flake-module.nix
# (add ./hosts/<hostname>/flake-module.nix to imports)

# Install from the NixOS ISO
nixos-install --flake /mnt/home/<user>/Documents/nix#<hostname>

# Reboot
reboot
```

### Step 8: Post-Install Setup

```bash
# Set up secrets (if using sops-nix)
# 1. Generate age key
mkdir -p /var/lib/sops-nix
age-keygen -o /var/lib/sops-nix/key.txt

# 2. Add the public key to .sops.yaml
# 3. Encrypt secrets
sops secrets/secrets.yaml

# Set up Secure Boot (if using Lanzaboote)
# Full guide: docs/secure-boot.md
sudo sbctl create-keys
sudo sbctl enroll-keys --microsoft
# Then rebuild with nrb
```

## Adding a New Module

1. **Create module file** in the appropriate directory (`parts/system/`, `parts/hardware/`, `parts/apps/`, etc.):
   ```nix
   { inputs, ... }: {
     flake.nixosModules.<scope>-<name> = { config, lib, pkgs, ... }:
       let cfg = config.myModules.<scope>.<name>;
       in {
         _class = "nixos";
         options.myModules.<scope>.<name> = {
           enable = lib.mkEnableOption "Description of the feature";
           # Add sub-options with lib.mkOption + description
         };
         config = lib.mkIf cfg.enable {
           # NixOS config here
         };
       };
   }
   ```

2. **Register in `parts/flake-module.nix`** — add the import.

3. **Import in host's `flake-module.nix`** — add `inputs.self.nixosModules.<scope>-<name>`.

4. **Enable in host's `default.nix`:** `myModules.<scope>.<name>.enable = true;`

5. **Regenerate docs:** `bash scripts/update-docs.sh`

### Conventions

- Use `lib.mkEnableOption` + `lib.mkIf cfg.enable` for all modules
- Use `lib.mkDefault` for defaults that hosts should override
- Every `lib.mkOption` must have a `description` string
- Gate vendor-specific config: `lib.optionals (config.myModules.hardware.graphics.amd.enable or false) [...]`
- Keep modules single-responsibility — if it covers two concerns, split it
- No hardcoded usernames, paths, or hardware identifiers in generic modules — use `config.myModules.primaryUser` for the username
- Host-specific values (UUIDs, connectors, profile names, product IDs) belong in `parts/hosts/<hostname>/default.nix`
- All modules include `_class = "nixos"` for type-safe module composition
- Use `types.lazyAttrsOf` for attrs-of-submodule options
- Use `withSystem` from flake-parts to access per-system inputs in NixOS modules

## Flake Inputs

| Input | Description |
|-------|-------------|
| `nixpkgs` | NixOS unstable channel |
| `flake-parts` | Modular flake framework |
| `nix-cachyos-kernel` | CachyOS kernel packages (pinned nixpkgs — do not override) |
| `home-manager` | User environment management |
| `plasma-manager` | KDE Plasma configuration via Home Manager |
| `nix-flatpak` | Declarative Flatpak management |
| `lanzaboote` | Secure Boot for NixOS |
| `sops-nix` | Secrets management with SOPS |
| `yeetmouse` / `yeetmouse-src` | Custom mouse acceleration driver |
| `cachyos-settings-nix` | CachyOS system optimization module |
| `tidalcycles` | Live coding music environment |
| `antigravity` | Antigravity IDE |
| `eden` | Nintendo Switch emulator (community fork) |
| `nx-save-sync` | Switch save sync tool |
| `portmaster` | Portmaster network firewall |
| `occt-nix` | OCCT stability test & benchmark |
| `claude-code` | Claude Code AI assistant |
| `mesa-git-nix` | Bleeding-edge Mesa from git main |
| `lsfg-vk` | Vulkan frame generation (Lossless Scaling) |
| `vkbasalt-overlay` | vkBasalt Vulkan post-processing overlay |
| `treefmt-nix` | Unified code formatting via flake-parts |
| `git-hooks-nix` | Pre-commit hooks via flake-parts |
| `disko` | Declarative disk partitioning |
| `impermanence` | Opt-in state persistence for ephemeral root |

## Development Tools

### Code Quality (treefmt + git-hooks)

The project uses [treefmt-nix](https://github.com/numtide/treefmt-nix) for unified formatting and [git-hooks.nix](https://github.com/cachix/git-hooks.nix) for pre-commit validation:

```bash
nix fmt                    # Format all files (nixfmt, shfmt, shellcheck, deadnix, statix)
nix flake check            # Run all checks (formatting + VM tests)
nix develop                # Enter devShell with pre-commit hooks auto-installed
```

Formatters: `nixfmt` (official Nix formatter), `deadnix` (unused binding removal), `statix` (anti-pattern detection), `shfmt` (shell formatting), `shellcheck` (shell linting).

### NixOS VM Tests

Integration tests verify key modules work correctly in isolated VMs:

```bash
nix build .#checks.x86_64-linux.vm-nix-settings   # Test nix daemon config
nix build .#checks.x86_64-linux.vm-users           # Test user creation
nix build .#checks.x86_64-linux.vm-ssh             # Test SSH hardening
nix build .#checks.x86_64-linux.vm-networking      # Test NetworkManager
```

### Claude Code Skills

Custom slash commands for common workflows (in `.claude/commands/`):

| Command | Description |
|---------|-------------|
| `/build` | Run `nrb` with optional flags |
| `/deploy` | Build locally and deploy to a remote host over SSH |
| `/rollback` | Rollback to previous NixOS generation |
| `/diff` | Show changes since last commit or between generations |
| `/info` | System state, kernel, generations, store size |
| `/gc` | Garbage collect and optimize Nix store |
| `/check` | Run all flake checks (formatting, linting, VM tests) |
| `/fmt` | Format all code with treefmt |
| `/test` | Run NixOS VM integration tests |
| `/audit` | Audit configuration for issues and best practices |
| `/security-audit` | Security-focused audit (SSH, firewall, secrets) |
| `/add-module` | Scaffold a new module following conventions |
| `/new-host` | Scaffold a complete new host configuration |
| `/search-option` | Search for myModules options |
| `/option-coverage` | Analyze option usage across hosts |
| `/compare-hosts` | Compare configurations between hosts |
| `/update-input` | Update flake inputs and verify build |
| `/update-docs` | Regenerate all documentation |
| `/profile-readme` | Sync GitHub profile README with project stats |
| `/repos` | Manage external package repositories |
| `/impermanence` | Guide impermanence setup and migration |

## Secrets Management

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix):

- **Encrypted secrets**: `secrets/secrets.yaml`
- **Age key**: `/var/lib/sops-nix/key.txt`
- **Configuration**: `parts/system/sops.nix`

### Setup

```bash
# Generate age key (once per machine)
sudo mkdir -p /var/lib/sops-nix
sudo age-keygen -o /var/lib/sops-nix/key.txt

# Get the public key
sudo age-keygen -y /var/lib/sops-nix/key.txt
# Add this public key to .sops.yaml

# Encrypt/edit secrets
sops secrets/secrets.yaml
```

### Recovery

If the age key is lost, secrets cannot be decrypted. Keep a backup of `/var/lib/sops-nix/key.txt` in a secure location.

For Secure Boot setup and recovery after BIOS updates, see [docs/secure-boot.md](docs/secure-boot.md). For installation from a live USB, see [docs/installation.md](docs/installation.md).

## Documentation

Module option documentation is auto-generated from `myModules` option definitions:

```bash
bash scripts/update-docs.sh           # Manual regeneration
bash scripts/test-shell-functions.sh  # Validate all configs, flags, functions, and docs
```

After every successful `nrb` switch, `docs/OPTIONS.md` is automatically regenerated in the background.

The pipeline: `scripts/generate-docs.nix` evaluates the `ryzen-9950x3d` NixOS configuration, extracts all `myModules.*` options (types, defaults, descriptions), groups them by category, and produces a Markdown file with table of contents. `scripts/update-docs.sh` is a wrapper that runs the Nix build and copies the result to `docs/OPTIONS.md`.

`scripts/test-shell-functions.sh` validates all configurations (including specialisations), verifies nrb flags and functions match the zsh source, and checks documentation completeness. It auto-extracts flags and function names from the zsh module, so it stays in sync without manual updates.

See [docs/OPTIONS.md](docs/OPTIONS.md) for the full reference (200+ options across 13 categories).

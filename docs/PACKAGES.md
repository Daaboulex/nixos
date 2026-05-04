# Custom Packages & Patches

This flake includes several custom-built packages, driver patches, and scripts that go beyond standard NixOS configuration.

## YeetMouse Driver (`parts/input/yeetmouse.nix`)

Custom mouse acceleration driver with 8 acceleration modes (linear, power, classic, motivity, synchronous, natural, jump, LUT). Includes:

- **LLVM/Clang build detection** — automatically detects CachyOS LLVM kernels and uses `clang`/`ld.lld` for module compilation
- **Kernel patches** — converts `printk()` calls to proper `KERN_INFO`/`KERN_ERR` levels
- **GUI patches** — fixes hardcoded exponent slider limits (allows 0.00 for Jump mode), hides unnecessary root privilege warning
- **Upstream parameter application** — the `driver.nix` module writes acceleration settings to sysfs via udev on any HID mouse connect. Configure parameters through `myModules.input.yeetmouse` options (sensitivity, mode, rotation, etc.)
- **G502 device module** — libinput HWDB entries force flat acceleration profile for wired (`c08d`) and Lightspeed wireless (`c539`) variants. This prevents libinput from applying additional acceleration on top of YeetMouse's custom curve. DPI and polling rate are configurable.

Options: `myModules.input.yeetmouse` (acceleration parameters), `myModules.input.yeetmouse.devices.g502` (HWDB flat profile, product IDs, DPI).

## Mesa-Git (`parts/hardware/graphics.nix`)

Bleeding-edge Mesa builds from git main (critical for RDNA 4 optimizations). Features:

- **Vendor-specific compilation** — optionally build only AMD, Intel, or NVIDIA drivers to reduce build time
- **32-bit support** — separate `mkMesaGit32` for Steam/Wine compatibility
- **Automatic fallback** — standard Mesa used when `mesaGit.enable = false`

Options: `myModules.hardware.graphics.mesaGit.enable`, `mesaGit.drivers = [ "amd" ]`.

## GoXLR Audio Interface (`parts/hardware/goxlr.nix`)

Full GoXLR Mini/Full support with:

- **ALSA UCM patch** — fixes GoXLR Mini HiFi channel count (`HWChannels 23` -> `21`)
- **PipeWire parametric EQ** — per-channel filter-chain modules (System, Game, Chat, Music, Sample) with DT990 Pro preset
- **DeepFilterNet3 neural denoise** — two-stage chain: 120Hz highpass filter + DeepFilterNet3 LADSPA neural noise suppression on chat mic. Configurable attenuation limits, ERB/DF thresholds, processing buffers.
- **Profile toggle script** — `goxlr-toggle` switches between Active and Sleep profiles for both device and microphone via `goxlr-client`

Options: `myModules.goxlr.enable`, `eq.enable`, `denoise.enable`, `toggle.enable`, per-channel sink overrides, EQ presets.

## StreamController Patch (`parts/input/streamcontroller.nix`)

Patches StreamController (Elgato Stream Deck app) to add USB websocket support and fix Elgato USB vendor ID resolution.

## KWin Scripts (`home/modules/plasma/default.nix`)

Two custom KWin scripts built as derivations:

- **late-tile** — watches for windows whose `WM_CLASS` changes after initial mapping (Electron, Flatpak apps) and retiles them once the class stabilizes. Without this, these apps get placed as floating windows instead of tiling.
- **Fluid Tile v7** — auto-tiling KWin script (from Codeberg) with extensive configuration: blocklist for apps that break when tiled, tile priority, overflow handling, layout cycling, dynamic desktop management.

## Display Management (`home/modules/displays/default.nix`)

Auto-generated scripts from `myModules.desktop.displays` monitor definitions:

- **`display-arrange`** — kscreen-doctor commands to set resolution, refresh rate, position, rotation, and VRR for each monitor. Runs at login and after sleep/wake.
- **Per-monitor toggle scripts** (e.g., `crt-toggle`) — enable/disable monitors with KWin D-Bus window migration (moves windows off the screen before disabling), repositions other monitors, reconfigures KWin.
- **Tiling activation** — writes per-monitor tile layouts to KWin config (using monitor UUIDs), purges stale/phantom entries.
- **systemd user services** — `display-arrange` (login), `display-arrange-wake` (post-sleep with output detection delay).

## Custom Scripts

- **sysdiag** (591 lines) — comprehensive NixOS system diagnostics: CPU, GPU, memory, storage, network, services, kernel, scheduler, display, errors. Auto-detects AMD/Intel/NVIDIA hardware and shows hardware-specific metrics (P-State, GPU clocks, NVMe temps, scx status).
- **list-iommu-groups** — lists IOMMU groups for GPU passthrough planning.
- **linux-corecycler** — Qt6 GUI for per-core CPU stress testing and AMD PBO Curve Optimizer tuning. Tests one core at a time at full single-threaded boost to find per-core CO limits. Supports mprime, stress-ng, and y-cruncher backends. X3D-aware topology detection. Runtime CO read/write via ryzen_smu (Zen 2–5). Volatile-only writes — never touches BIOS.

## VFIO Stealth GPU Passthrough (`parts/vfio/`)

Declarative VFIO GPU passthrough with anti-cheat stealth for Windows gaming VMs:

- **Per-VM definitions** — typed `vms.<name>` options for UUID, vCPU pinning, memory, disk, PCI passthrough, CPU identity spoofing
- **Dynamic GPU binding** — libvirt hooks unbind GPU from `amdgpu` → bind to `vfio-pci` on VM start, reverse on stop
- **Stealth QEMU** — patched QEMU (via overlay) removes all "QEMU"/"BOCHS"/"VirtIO" device signatures, ACPI/SMBIOS spoofing
- **KVM kernel patches** — RDTSC timing spoofing and CPUID masking at the KVM level (applied via `boot.kernelPatches`)
- **CPU identity spoofing** — per-VM CPUID brand string override (e.g., spoof CCD0 as Ryzen 7 9850X3D)
- **Looking Glass** — KVMFR shared memory for viewing VM display on host without a separate monitor
- **Evdev input** — keyboard/mouse passthrough with host/guest toggle
- **Hugepages** — 1GB/2MB static allocation for VM memory (fewer TLB misses)
- **NixVirt integration** — declarative libvirt domain XML generation from Nix attrsets

Options: `myModules.vfio.{enable,bindMethod,stealth,kvmfr,evdev,hugepages,vms.<name>}` — see [OPTIONS.md](OPTIONS.md).

## Arkenfox Auto-Update (`home/modules/arkenfox/default.nix`)

Systemd service + timer that downloads the latest Arkenfox `user.js` Firefox security hardening config. Runs daily with retry on failure. Supports Flatpak Firefox/LibreWolf profiles.

## Gaming Stack (`parts/gaming/`)

Integrated gaming performance and visual enhancement stack:

- **GameMode** — per-game performance daemon: X3D V-Cache CCD mode switching, core pinning to V-Cache CCD, governor EPP hint (powersave→performance), GPU `power_dpm_force_performance_level=high`. Renice/ioprio disabled to avoid conflict with ananicy-cpp.
- **vkBasalt Overlay** — Vulkan post-processing layer with in-game ImGui UI for real-time effect tuning (Wayland + X11). Fork of [vkBasalt overlay](https://github.com/Boux/vkBasalt_overlay) with full Wayland input support. Ships with 15 modular ReShade shader collections (crosire, SweetFX, prod80, AstrayFX, fubax, qUINT, iMMERSE, METEOR, Insane, Daodan, FXShaders, potatoFX, CShade, ZenteonFX, HDR) — combined into a single shader directory. Configurable via `myModules.home.vkbasalt` options (effects, casSharpness, overlayKey, toggleKey, shaderPackages, extraConfig)
- **MangoHud + MangoJuice** — FPS/GPU/CPU overlay (MangoHud) with a GUI configurator (MangoJuice)
- **Steam** — with Proton-GE, Gamescope session support, and steam-devices udev rules
- **Emulators** — Ryubing (Switch), Eden (Switch community fork), Azahar (3DS), Prism Launcher (Minecraft)

### vkBasalt Overlay Usage

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

### Scheduler & Performance Stack (5 layers)

| Layer | Component         | What it does                                                                              |
| ----- | ----------------- | ----------------------------------------------------------------------------------------- |
| 1     | **amd_3d_vcache** | Firmware CCD routing (V-Cache vs frequency CCD). GameMode switches mode per-game.         |
| 2     | **amd_pstate**    | CPPC frequency scaling via EPP hints. Governor: `powersave` (dynamic, boosts to max).     |
| 3     | **BORE**          | CachyOS default kernel scheduler — burst-aware, low-latency.                              |
| 4     | **scx_lavd**      | BPF scheduler overlay — latency-aware virtual deadline scheduling.                        |
| 5     | **ananicy-cpp**   | CachyOS process priority rules (nice/ionice). GameMode renice disabled to avoid conflict. |

Options: `myModules.gaming.*` — see [OPTIONS.md](OPTIONS.md) for all gaming options.

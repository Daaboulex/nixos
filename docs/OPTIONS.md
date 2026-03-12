# NixOS Custom Modules Documentation

> Auto-generated from `myModules` option definitions. 237 options across 13 categories.
>
> Regenerate: `bash scripts/update-docs.sh`

## Table of Contents

- [AUDIO](#audio-35-options) (35 options)
- [CACHYOS](#cachyos-15-options) (15 options)
- [DESKTOP](#desktop-8-options) (8 options)
- [DEVELOPMENT](#development-3-options) (3 options)
- [GAMING](#gaming-33-options) (33 options)
- [HARDWARE](#hardware-56-options) (56 options)
- [KERNEL](#kernel-14-options) (14 options)
- [MUSIC](#music-2-options) (2 options)
- [PRIMARYUSER](#primaryuser-1-options) (1 options)
- [PROGRAMS](#programs-3-options) (3 options)
- [SECURITY](#security-17-options) (17 options)
- [SYSTEM](#system-48-options) (48 options)
- [TOOLS](#tools-2-options) (2 options)

---
## AUDIO (35 options)

#### `myModules.audio.goxlr.denoise.attenuationLimit`

**Description**: Max noise attenuation in dB (0-100). 100 = no limit (official default). 6-12 = light, 18-24 = medium.
- **Type**: `signed integer`
- **Default**: `100`


#### `myModules.audio.goxlr.denoise.enable`

**Description**: Whether to enable DeepFilterNet3 neural noise suppression on chat mic.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.audio.goxlr.denoise.maxDfThreshold`

**Description**: Max DF processing threshold in dB (-15 to 35). Lower suppresses transient noise (claps, bumps). Below 10 risks affecting plosives.
- **Type**: `floating point number`
- **Default**: `12.0`


#### `myModules.audio.goxlr.denoise.maxErbThreshold`

**Description**: Max ERB processing threshold in dB (-15 to 35). Lower reduces muffling on loud speech.
- **Type**: `floating point number`
- **Default**: `20.0`


#### `myModules.audio.goxlr.denoise.minProcessingBuffer`

**Description**: Min processing buffer in frames (0-10). 0 = lowest latency.
- **Type**: `signed integer`
- **Default**: `0`


#### `myModules.audio.goxlr.denoise.minThreshold`

**Description**: Min processing threshold in dB (-15 to 35).
- **Type**: `floating point number`
- **Default**: `-15.0`


#### `myModules.audio.goxlr.denoise.postFilterBeta`

**Description**: Post-filter beta (0-0.05). 0 = disabled. DF3 is sufficient without it; higher values muffle voice.
- **Type**: `floating point number`
- **Default**: `0.0`


#### `myModules.audio.goxlr.denoise.source`

**Description**: PipeWire node name of the raw microphone source
- **Type**: `string`
- **Default**: `"alsa_input.usb-TC-Helicon_GoXLR-00.HiFi__Headset__source"`


#### `myModules.audio.goxlr.enable`

**Description**: Whether to enable GoXLR Mini support.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.audio.goxlr.eq.channels.chat.enable`

**Description**: Whether to enable EQ for Chat channel.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.audio.goxlr.eq.channels.chat.eq`

**Description**: PipeWire filter-chain EQ filter definition for Chat channel
- **Type**: `string`
- **Default**: `"filters = [\n  { type = bq_highshelf, freq = 0, gain = -5.23, q = 1.0 },\n  { type = bq_lowshelf, freq = 105.0, gain...`


#### `myModules.audio.goxlr.eq.channels.chat.sink`

**Description**: PipeWire sink node name for Chat channel
- **Type**: `string`
- **Default**: `"alsa_output.usb-TC-Helicon_GoXLR-00.HiFi__Headphones__sink"`


#### `myModules.audio.goxlr.eq.channels.game.enable`

**Description**: Whether to enable EQ for Game channel.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.audio.goxlr.eq.channels.game.eq`

**Description**: PipeWire filter-chain EQ filter definition for Game channel
- **Type**: `string`
- **Default**: `"filters = [\n  { type = bq_highshelf, freq = 0, gain = -5.23, q = 1.0 },\n  { type = bq_lowshelf, freq = 105.0, gain...`


#### `myModules.audio.goxlr.eq.channels.game.sink`

**Description**: PipeWire sink node name for Game channel
- **Type**: `string`
- **Default**: `"alsa_output.usb-TC-Helicon_GoXLR-00.HiFi__Line1__sink"`


#### `myModules.audio.goxlr.eq.channels.music.enable`

**Description**: Whether to enable EQ for Music channel.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.audio.goxlr.eq.channels.music.eq`

**Description**: PipeWire filter-chain EQ filter definition for Music channel
- **Type**: `string`
- **Default**: `"filters = [\n  { type = bq_highshelf, freq = 0, gain = -5.23, q = 1.0 },\n  { type = bq_lowshelf, freq = 105.0, gain...`


#### `myModules.audio.goxlr.eq.channels.music.sink`

**Description**: PipeWire sink node name for Music channel
- **Type**: `string`
- **Default**: `"alsa_output.usb-TC-Helicon_GoXLR-00.HiFi__Line2__sink"`


#### `myModules.audio.goxlr.eq.channels.sample.enable`

**Description**: Whether to enable EQ for Sample channel.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.audio.goxlr.eq.channels.sample.eq`

**Description**: PipeWire filter-chain EQ filter definition for Sample channel
- **Type**: `string`
- **Default**: `"filters = [\n  { type = bq_highshelf, freq = 0, gain = -5.23, q = 1.0 },\n  { type = bq_lowshelf, freq = 105.0, gain...`


#### `myModules.audio.goxlr.eq.channels.sample.sink`

**Description**: PipeWire sink node name for Sample channel
- **Type**: `string`
- **Default**: `"alsa_output.usb-TC-Helicon_GoXLR-00.HiFi__Line3__sink"`


#### `myModules.audio.goxlr.eq.channels.system.enable`

**Description**: Whether to enable EQ for System channel.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.audio.goxlr.eq.channels.system.eq`

**Description**: PipeWire filter-chain EQ filter definition for System channel
- **Type**: `string`
- **Default**: `"filters = [\n  { type = bq_highshelf, freq = 0, gain = -5.23, q = 1.0 },\n  { type = bq_lowshelf, freq = 105.0, gain...`


#### `myModules.audio.goxlr.eq.channels.system.sink`

**Description**: PipeWire sink node name for System channel
- **Type**: `string`
- **Default**: `"alsa_output.usb-TC-Helicon_GoXLR-00.HiFi__Speaker__sink"`


#### `myModules.audio.goxlr.eq.clearStreamProperties`

**Description**: Clear PipeWire stream properties before applying EQ filters
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.audio.goxlr.eq.enable`

**Description**: Whether to enable PipeWire parametric EQ for GoXLR channels.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.audio.goxlr.eq.presets`

**Description**: Built-in EQ presets (read-only). Use as values for channel eq options.
- **Type**: `attribute set of string`
- **Default**: `{"dt990pro":"filters = [\n  { type = bq_highshelf, freq = 0, gain = -5.23, q = 1.0 },\n  { type = bq_lowshelf, freq =...`


#### `myModules.audio.goxlr.installProfiles`

**Description**: Install custom GoXLR UCM profiles
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.audio.goxlr.isMini`

**Description**: Apply GoXLR Mini UCM patch
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.audio.goxlr.toggle.activeMicProfile`

**Description**: Microphone profile to load when waking (active state)
- **Type**: `string`
- **Default**: `"Default"`


#### `myModules.audio.goxlr.toggle.activeProfile`

**Description**: Device profile to load when waking (active state)
- **Type**: `string`
- **Default**: `"Default"`


#### `myModules.audio.goxlr.toggle.enable`

**Description**: Whether to enable goxlr-toggle script for switching between active and sleep profiles.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.audio.goxlr.toggle.sleepMicProfile`

**Description**: Microphone profile to load when sleeping
- **Type**: `string`
- **Default**: `"Sleep"`


#### `myModules.audio.goxlr.toggle.sleepProfile`

**Description**: Device profile to load when sleeping
- **Type**: `string`
- **Default**: `"Sleep"`


#### `myModules.audio.goxlr.utility.enable`

**Description**: goxlr-utility daemon
- **Type**: `boolean`
- **Default**: `true`



## CACHYOS (15 options)

#### `myModules.cachyos.settings.amdgpuGcnCompat.enable`

**Description**: Whether to enable CachyOS amdgpuGcnCompat.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.cachyos.settings.audio.enable`

**Description**: Whether to enable CachyOS audio.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.cachyos.settings.coredump.enable`

**Description**: Whether to enable CachyOS coredump.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.cachyos.settings.debuginfod.enable`

**Description**: Whether to enable CachyOS debuginfod.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.cachyos.settings.enable`

**Description**: Whether to enable CachyOS system optimizations (upstream-matched settings).
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.cachyos.settings.extraPerformance.enable`

**Description**: Whether to enable Extra performance sysctls: BBR, cake, tcp_fastopen, buffer sizes, max_map_count, compaction, sched_autogroup.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.cachyos.settings.ioSchedulers.enable`

**Description**: Whether to enable CachyOS ioSchedulers.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.cachyos.settings.networkManager.enable`

**Description**: Whether to enable CachyOS networkManager.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.cachyos.settings.ntsync.enable`

**Description**: Whether to enable CachyOS ntsync.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.cachyos.settings.nvidia.enable`

**Description**: Whether to enable CachyOS nvidia.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.cachyos.settings.storage.enable`

**Description**: Whether to enable CachyOS storage.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.cachyos.settings.systemd.enable`

**Description**: Whether to enable CachyOS systemd.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.cachyos.settings.thp.enable`

**Description**: Whether to enable CachyOS thp.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.cachyos.settings.timesyncd.enable`

**Description**: Whether to enable CachyOS timesyncd.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.cachyos.settings.zram.enable`

**Description**: Whether to enable CachyOS zram.
- **Type**: `boolean`
- **Default**: `true`



## DESKTOP (8 options)

#### `myModules.desktop.displays.enable`

**Description**: Whether to enable declarative display configuration.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.desktop.displays.monitors`

**Description**: Monitor definitions
- **Type**: `lazy attribute set of (submodule)`
- **Default**: `{}`


#### `myModules.desktop.displays.phantomUuids`

**Description**: Stale monitor UUIDs to purge from tiling config
- **Type**: `list of string`
- **Default**: `[]`


#### `myModules.desktop.flatpak.enable`

**Description**: Whether to enable Flatpak support.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.desktop.kde.ddcBrightness`

**Description**: i2c for PowerDevil DDC brightness control
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.desktop.kde.enable`

**Description**: Whether to enable KDE Plasma Desktop Environment.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.desktop.kde.xkbLayout`

**Description**: XKB keyboard layout (e.g. 'us', 'de', 'us,de')
- **Type**: `string`
- **Default**: `"us"`


#### `myModules.desktop.kde.xkbVariant`

**Description**: XKB keyboard variant
- **Type**: `string`
- **Default**: `""`



## DEVELOPMENT (3 options)

#### `myModules.development.claudeCode`

**Description**: Whether to enable Claude Code AI assistant.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.development.enable`

**Description**: Whether to enable Development tools (compilers, build systems, AI assistants).
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.development.saleae`

**Description**: Whether to enable Saleae Logic analyzer and udev rules.
- **Type**: `boolean`
- **Default**: `false`



## GAMING (33 options)

#### `myModules.gaming.azahar.enable`

**Description**: Azahar
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.gaming.eden.enable`

**Description**: Eden
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.gaming.enable`

**Description**: Whether to enable Gaming optimizations and software.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.gaming.gamemode.desiredgov`

**Description**: CPU governor to set when a game starts (performance = aggressive EPP hint on amd_pstate)
- **Type**: `string`
- **Default**: `"performance"`


#### `myModules.gaming.gamemode.gpuPerformanceLevel`

**Description**: AMDGPU power_dpm_force_performance_level (null = don't set, auto = driver decides, high = max clocks)
- **Type**: `null or one of "auto", "low", "high"`
- **Default**: `null`


#### `myModules.gaming.gamemode.ioprio`

**Description**: IO priority for game processes (off = disabled to avoid ananicy-cpp conflict, or 0-7)
- **Type**: `string`
- **Default**: `"off"`


#### `myModules.gaming.gamemode.pinCores`

**Description**: Pin game to specific cores (yes = auto-detect, or core list like 0-7,16-23, no = disabled)
- **Type**: `string`
- **Default**: `"no"`


#### `myModules.gaming.gamemode.renice`

**Description**: Renice priority for gamemode-managed processes (0 = disabled, avoids conflict with ananicy-cpp)
- **Type**: `signed integer`
- **Default**: `0`


#### `myModules.gaming.gamemode.x3dMode.default`

**Description**: X3D V-Cache CCD mode when not gaming (restored on exit)
- **Type**: `null or one of "cache", "frequency"`
- **Default**: `null`


#### `myModules.gaming.gamemode.x3dMode.desired`

**Description**: X3D V-Cache CCD mode when gaming (cache = prefer V-Cache CCD, frequency = prefer high-clock CCD)
- **Type**: `null or one of "cache", "frequency"`
- **Default**: `null`


#### `myModules.gaming.gamescope.enable`

**Description**: Gamescope
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.gaming.gpuDevice`

**Description**: GPU device index for gamemode optimizations (0 = first GPU)
- **Type**: `signed integer`
- **Default**: `0`


#### `myModules.gaming.heroic.enable`

**Description**: Heroic Games Launcher
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.gaming.lsfgVk.enable`

**Description**: lsfg-vk Vulkan frame generation (requires Lossless Scaling)
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.gaming.mangohud.enable`

**Description**: MangoHud
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.gaming.nxSaveSync.enable`

**Description**: NX-Save-Sync
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.gaming.occt.enable`

**Description**: OCCT stability test
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.gaming.packages.cachyos`

**Description**: CachyOS optimized packages
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.gaming.packages.performance`

**Description**: Performance packages
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.gaming.prismlauncher.enable`

**Description**: Prism Launcher for Minecraft
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.gaming.protonplus.enable`

**Description**: Whether to enable ProtonPlus for managing Proton versions.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.gaming.radv.perftest`

**Description**: RADV_PERFTEST flags for AMD Vulkan driver (comma-separated)
- **Type**: `string`
- **Default**: `"gpl,nggc"`


#### `myModules.gaming.ryubing.enable`

**Description**: Ryubing
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.gaming.steam.enable`

**Description**: Steam
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.gaming.steam.gamescope`

**Description**: Gamescope session for Steam
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.gaming.vkbasalt.autoApply`

**Description**: Auto-apply parameter changes without clicking Apply
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.gaming.vkbasalt.casSharpness`

**Description**: Default CAS sharpness (0.0 = subtle, 1.0 = maximum)
- **Type**: `string`
- **Default**: `"0.4"`


#### `myModules.gaming.vkbasalt.effects`

**Description**: Default colon-separated effect chain (cas, smaa, fxaa, Vibrance, LiftGammaGain, Tonemap, etc.)
- **Type**: `string`
- **Default**: `"cas"`


#### `myModules.gaming.vkbasalt.enable`

**Description**: vkBasalt overlay — Vulkan post-processing with in-game UI
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.gaming.vkbasalt.enableOnLaunch`

**Description**: Effects enabled automatically when a game launches
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.gaming.vkbasalt.extraConfig`

**Description**: Extra lines for system config (ReShade shader parameters like Vibrance, LiftGammaGain values)
- **Type**: `strings concatenated with "\n"`
- **Default**: `""`


#### `myModules.gaming.vkbasalt.overlayKey`

**Description**: Key to open the overlay UI in-game
- **Type**: `string`
- **Default**: `"F1"`


#### `myModules.gaming.vkbasalt.toggleKey`

**Description**: Key to toggle effects on/off in-game
- **Type**: `string`
- **Default**: `"Home"`



## HARDWARE (56 options)

#### `myModules.hardware.audio.easyeffects.enable`

**Description**: Install EasyEffects audio effects processor
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.audio.enable`

**Description**: Whether to enable Audio configuration with PipeWire.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.audio.pipewire.lowLatency`

**Description**: Whether to enable Low latency configuration (48kHz, 128 samples).
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.bluetooth.enable`

**Description**: Whether to enable Bluetooth configuration.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.bluetooth.powerOnBoot`

**Description**: Power on Bluetooth controller on boot
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.core.enable`

**Description**: Whether to enable Core hardware configuration (firmware, microcode, sensors).
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.cpu.amd.enable`

**Description**: Whether to enable AMD CPU optimizations.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.cpu.amd.kvm.enable`

**Description**: KVM-AMD virtualization support
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.hardware.cpu.amd.prefcore.enable`

**Description**: AMD Preferred Core technology
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.hardware.cpu.amd.pstate.enable`

**Description**: AMD P-State driver for modern power management
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.hardware.cpu.amd.pstate.mode`

**Description**: AMD P-State mode (active recommended for Zen 3+)
- **Type**: `one of "active", "passive", "guided"`
- **Default**: `"active"`


#### `myModules.hardware.cpu.amd.updateMicrocode`

**Description**: Update AMD CPU microcode
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.hardware.cpu.amd.x3dVcache.enable`

**Description**: AMD 3D V-Cache optimizer (for dual-CCD X3D processors like 9950X3D/9900X3D)
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.cpu.amd.x3dVcache.mode`

**Description**: 3D V-Cache scheduling preference:
- "cache": prefer CCD with larger L3 cache (gaming, cache-sensitive workloads)
- "frequency": prefer CCD with higher clocks (productivity, compilation)
Requires BIOS CPPC option set to "Driver".

- **Type**: `one of "cache", "frequency"`
- **Default**: `"cache"`


#### `myModules.hardware.debuggingProbes.enable`

**Description**: Whether to enable Embedded debugging probes (LPC-Link2, ESP32) udev rules.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.duckyOneXMini.board.product`

**Description**: USB product ID for the keyboard board HID interface
- **Type**: `string`
- **Default**: `"001d"`


#### `myModules.hardware.duckyOneXMini.enable`

**Description**: Whether to enable Ducky One X Mini keyboard HID access (udev rules for VIA/Vial).
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.duckyOneXMini.mcu.product`

**Description**: USB product ID for the keyboard MCU HID interface
- **Type**: `string`
- **Default**: `"0021"`


#### `myModules.hardware.duckyOneXMini.vendor`

**Description**: USB vendor ID for the Ducky keyboard
- **Type**: `string`
- **Default**: `"3233"`


#### `myModules.hardware.graphics.amd.disableHDCP`

**Description**: Disable HDCP (amdgpu.dc_hdcp_enable=0) — fixes handshake bugs on RDNA 4
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.graphics.amd.drmDebug`

**Description**: DRM debug logging (drm.debug=0x1e) for diagnosing display black screens
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.graphics.amd.enable`

**Description**: Whether to enable AMD Graphics configuration.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.graphics.amd.enablePPFeatureMask`

**Description**: Full AMD GPU power management features (ppfeaturemask=0xffffffff)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.hardware.graphics.amd.initrd.enable`

**Description**: Load amdgpu in initrd (required for Plymouth)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.hardware.graphics.amd.lact.enable`

**Description**: LACT daemon for AMD GPU control/overclocking
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.hardware.graphics.amd.openCL`

**Description**: OpenCL support via RustiCL (Mesa) radeonsi driver
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.hardware.graphics.amd.rdna4Fixes`

**Description**: Apply RDNA 4 (GFX12) stability kernel params: disable scatter-gather display and GFX OFF
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.hardware.graphics.amd.vulkanDeviceId`

**Description**: Vulkan device vendor:device ID for MESA_VK_DEVICE_SELECT (forces discrete GPU on dual-AMD systems)
- **Type**: `null or string`
- **Default**: `null`


#### `myModules.hardware.graphics.amd.vulkanDeviceName`

**Description**: Vulkan device name substring for DXVK_FILTER_DEVICE_NAME and VKD3D_FILTER_DEVICE_NAME (forces dGPU for translated DX9-12 games)
- **Type**: `null or string`
- **Default**: `null`


#### `myModules.hardware.graphics.enable`

**Description**: Whether to enable Graphics support.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.graphics.enable32Bit`

**Description**: 32-bit graphics support
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.hardware.graphics.mesaGit.drivers`

**Description**: GPU vendors to compile drivers for. Only the selected vendor drivers
plus common essentials (llvmpipe, zink, virgl, swrast) are built.

Use multiple entries for multi-GPU setups (e.g. Intel iGPU + NVIDIA dGPU).
An empty list (default) builds all drivers.

- **Type**: `list of (one of "amd", "intel", "nvidia")`
- **Default**: `[]`


#### `myModules.hardware.graphics.mesaGit.enable`

**Description**: Whether to enable mesa-git (bleeding-edge) instead of nixpkgs mesa.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.graphics.openCL.rusticlDrivers`

**Description**: Gallium drivers to enable in RustiCL (Mesa's OpenCL implementation).
GPU vendor modules append their driver automatically when their openCL
option is enabled. Set by gpu-amd (radeonsi) and gpu-intel (iris).
Assembled into RUSTICL_ENABLE session variable as a comma-separated list.

- **Type**: `list of string`
- **Default**: `[]`


#### `myModules.hardware.networking.enable`

**Description**: Whether to enable Networking configuration.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.networking.nameservers`

**Description**: DNS nameservers (default: Quad9)
- **Type**: `list of string`
- **Default**: `["9.9.9.9","149.112.112.112","2620:fe::fe","2620:fe::9"]`


#### `myModules.hardware.networking.openPortRanges`

**Description**: List of TCP port ranges to open (e.g. [{ from = 1000; to = 2000; }])
- **Type**: `list of (attribute set)`
- **Default**: `[]`


#### `myModules.hardware.networking.openPorts`

**Description**: List of TCP ports to open
- **Type**: `list of signed integer`
- **Default**: `[]`


#### `myModules.hardware.performance.ananicy`

**Description**: Ananicy-cpp process prioritization
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.hardware.performance.enable`

**Description**: Whether to enable Performance tuning and optimization.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.performance.governor`

**Description**: CPU frequency governor
- **Type**: `string`
- **Default**: `"powersave"`


#### `myModules.hardware.performance.irqbalance`

**Description**: IRQ balancing across CPU cores
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.hardware.performance.scx.enable`

**Description**: Whether to enable Sched-ext (scx) userspace CPU schedulers.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.performance.scx.extraArgs`

**Description**: Extra arguments passed to the scheduler
- **Type**: `list of string`
- **Default**: `[]`


#### `myModules.hardware.performance.scx.scheduler`

**Description**: Which SCX scheduler to run
- **Type**: `one of "scx_lavd", "scx_bpfland", "scx_cosmos", "scx_rusty", "scx_rustland", "scx_flash", "scx_p2dq", "scx_beerland", "scx_mitosis", "scx_tickless", "scx_central", "scx_nest", "scx_layered"`
- **Default**: `"scx_lavd"`


#### `myModules.hardware.piper.enable`

**Description**: Whether to enable Piper mouse configuration tool and ratbagd service.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.power.enable`

**Description**: Whether to enable Power management configuration.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.power.laptop`

**Description**: Whether to enable Laptop power optimizations (TLP).
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.power.profile`

**Description**: Power profile to apply
- **Type**: `one of "performance", "balanced", "powersave"`
- **Default**: `"balanced"`


#### `myModules.hardware.streamcontroller.enable`

**Description**: Whether to enable StreamController (Elgato Stream Deck).
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.yeetmouse.devices.g502.dpi`

**Description**: Mouse DPI setting (reported to libinput via HWDB)
- **Type**: `signed integer`
- **Default**: `1600`


#### `myModules.hardware.yeetmouse.devices.g502.enable`

**Description**: Whether to enable Libinput flat acceleration profile for Logitech G502 (Wired/Wireless).
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.hardware.yeetmouse.devices.g502.pollingRate`

**Description**: Mouse polling rate in Hz (reported to libinput via HWDB)
- **Type**: `signed integer`
- **Default**: `1000`


#### `myModules.hardware.yeetmouse.devices.g502.wiredProductId`

**Description**: USB product ID for the wired G502 (check with lsusb)
- **Type**: `string`
- **Default**: `"c08d"`


#### `myModules.hardware.yeetmouse.devices.g502.wirelessProductId`

**Description**: USB product ID for the Lightspeed Receiver
- **Type**: `string`
- **Default**: `"c539"`


#### `myModules.hardware.yeetmouse.enable`

**Description**: Whether to enable YeetMouse input driver.
- **Type**: `boolean`
- **Default**: `false`



## KERNEL (14 options)

#### `myModules.kernel.cachyos.bbr3`

**Description**: BBR3 TCP congestion control
- **Type**: `null or boolean`
- **Default**: `null`


#### `myModules.kernel.cachyos.ccHarder`

**Description**: -O3 optimizations
- **Type**: `null or boolean`
- **Default**: `null`


#### `myModules.kernel.cachyos.cpusched`

**Description**: CPU scheduler (e.g. bmq, bore, eevdf)
- **Type**: `null or string`
- **Default**: `null`


#### `myModules.kernel.cachyos.hugepage`

**Description**: Transparent Hugepage behavior (e.g. always, madvise)
- **Type**: `null or string`
- **Default**: `null`


#### `myModules.kernel.cachyos.hzTicks`

**Description**: Timer frequency (e.g. 1000, 500, 300)
- **Type**: `null or string`
- **Default**: `null`


#### `myModules.kernel.cachyos.kcfi`

**Description**: KCFI (Kernel Control Flow Integrity)
- **Type**: `null or boolean`
- **Default**: `null`


#### `myModules.kernel.cachyos.performanceGovernor`

**Description**: Default to performance governor
- **Type**: `null or boolean`
- **Default**: `null`


#### `myModules.kernel.cachyos.preemptType`

**Description**: Preemption model (e.g. full, voluntary)
- **Type**: `null or string`
- **Default**: `null`


#### `myModules.kernel.cachyos.tickrate`

**Description**: Tickless behavior (e.g. full, idle)
- **Type**: `null or string`
- **Default**: `null`


#### `myModules.kernel.channel`

**Description**: CachyOS kernel channel: latest (stable bleeding-edge), lts (long-term support), rc (release candidate)
- **Type**: `one of "latest", "lts", "rc"`
- **Default**: `"latest"`


#### `myModules.kernel.enable`

**Description**: Whether to enable Custom kernel configuration.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.kernel.extraParams`

**Description**: Extra kernel parameters
- **Type**: `list of string`
- **Default**: `[]`


#### `myModules.kernel.mArch`

**Description**: Microarchitecture for CachyOS kernel (x86-64-v3, x86-64-v4, ZEN4, ZEN5, etc.)
- **Type**: `string`
- **Default**: `"x86-64-v3"`


#### `myModules.kernel.variant`

**Description**: Kernel variant to use (cachyos, zen, xanmod, or NixOS default)
- **Type**: `one of "cachyos", "cachyos-lto", "cachyos-sched-ext", "zen", "xanmod", "default"`
- **Default**: `"default"`



## MUSIC (2 options)

#### `myModules.music.tidalcycles.autostartSuperDirt`

**Description**: Auto-start SuperDirt (SuperCollider) as a systemd user service
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.music.tidalcycles.enable`

**Description**: Whether to enable TidalCycles and SuperDirt.
- **Type**: `boolean`
- **Default**: `false`



## PRIMARYUSER (1 options)

#### `myModules.primaryUser`

**Description**: Primary system username used across all modules
- **Type**: `string`
- **Default**: `"user"`



## PROGRAMS (3 options)

#### `myModules.programs.bottles.enable`

**Description**: Whether to enable Bottles installation.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.programs.wine.enable`

**Description**: Whether to enable Wine installation.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.programs.wine.variant`

**Description**: Wine variant (staging has more patches, Full includes all optional deps)
- **Type**: `one of "stable", "staging", "stableFull", "stagingFull"`
- **Default**: `"stagingFull"`



## SECURITY (17 options)

#### `myModules.security.arkenfox.enable`

**Description**: Whether to enable Arkenfox Firefox security configuration.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.security.arkenfox.group`

**Description**: Group to run the service as
- **Type**: `string`
- **Default**: `"users"`


#### `myModules.security.arkenfox.targetDir`

**Description**: Target directory for Firefox profile
- **Type**: `string`
- **Default**: `"<no default>"`


#### `myModules.security.arkenfox.user`

**Description**: User to run the service as
- **Type**: `string`
- **Default**: `"user"`


#### `myModules.security.portmaster.autostart`

**Description**: Whether portmaster.service starts automatically on boot. When false, the service is installed but must be started manually with `sudo systemctl start portmaster`.
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.security.portmaster.enable`

**Description**: Whether to enable Portmaster privacy firewall.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.security.portmaster.extraArgs`

**Description**: Extra command-line arguments for portmaster-core
- **Type**: `list of string`
- **Default**: `[]`


#### `myModules.security.portmaster.notifier`

**Description**: Whether to enable Portmaster system tray notifier (autostart).
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.security.portmaster.settings`

**Description**: Portmaster settings passed to portmaster-core
- **Type**: `attribute set`
- **Default**: `{}`


#### `myModules.security.sops.ageKeyFile`

**Description**: Path to the age key file
- **Type**: `string`
- **Default**: `"/var/lib/sops-nix/key.txt"`


#### `myModules.security.sops.defaultSopsFile`

**Description**: Default sops file
- **Type**: `absolute path`
- **Default**: `"/nix/store/hma3lbvka67m3i58xkg8pzm9p6pavxd5-secrets.yaml"`


#### `myModules.security.sops.enable`

**Description**: Whether to enable sops-nix secret management.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.security.ssh.enable`

**Description**: Whether to enable Secure SSH server configuration.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.security.ssh.fail2banIgnoreIPs`

**Description**: IP ranges to never ban (add your LAN/VPN subnets)
- **Type**: `list of string`
- **Default**: `["127.0.0.1/8","::1/128"]`


#### `myModules.security.ssh.trustedKeys`

**Description**: List of trusted SSH public keys
- **Type**: `list of string`
- **Default**: `[]`


#### `myModules.security.system.enable`

**Description**: Whether to enable System-wide security hardening.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.security.system.firejail.enable`

**Description**: Firejail sandboxing
- **Type**: `boolean`
- **Default**: `false`



## SYSTEM (48 options)

#### `myModules.system.boot.consoleMode`

**Description**: Console resolution mode (max, keep, or specific like 1920x1080)
- **Type**: `null or string`
- **Default**: `"max"`


#### `myModules.system.boot.enable`

**Description**: Whether to enable Boot configuration.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.system.boot.initrd.enable`

**Description**: Systemd initrd for Plymouth
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.boot.loader`

**Description**: Bootloader to use
- **Type**: `one of "systemd-boot", "grub", "none"`
- **Default**: `"systemd-boot"`


#### `myModules.system.boot.plymouth.enable`

**Description**: Whether to enable Plymouth boot splash.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.system.boot.plymouth.theme`

**Description**: Plymouth theme to use
- **Type**: `string`
- **Default**: `"bgrt"`


#### `myModules.system.boot.secureBoot.enable`

**Description**: Whether to enable Lanzaboote secure boot.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.system.boot.secureBoot.pkiBundle`

**Description**: Path to PKI bundle
- **Type**: `absolute path`
- **Default**: `"/var/lib/sbctl"`


#### `myModules.system.filesystems.enable`

**Description**: Whether to enable Universal filesystem support.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.system.filesystems.enableAll`

**Description**: All filesystem categories (overrides individual toggles)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.filesystems.enableLegacy`

**Description**: Legacy filesystems (ReiserFS)
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.system.filesystems.enableLinux`

**Description**: Linux filesystems (ext4, btrfs, xfs, f2fs)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.filesystems.enableMac`

**Description**: macOS filesystems (HFS+)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.filesystems.enableOptical`

**Description**: Optical disc filesystems (ISO 9660, UDF)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.filesystems.enableWindows`

**Description**: Windows filesystems (NTFS, exFAT, FAT32)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.impermanence.enable`

**Description**: Whether to enable Impermanence (erase root on every boot).
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.system.impermanence.extraDirectories`

**Description**: Extra system directories to persist
- **Type**: `list of (string or (attribute set))`
- **Default**: `[]`


#### `myModules.system.impermanence.extraFiles`

**Description**: Extra system files to persist
- **Type**: `list of string`
- **Default**: `[]`


#### `myModules.system.impermanence.luksDevice`

**Description**: LUKS device mapper name (e.g. cryptroot)
- **Type**: `string`
- **Default**: `"cryptroot"`


#### `myModules.system.impermanence.persistPath`

**Description**: Mountpoint for the persistent BTRFS subvolume
- **Type**: `absolute path`
- **Default**: `"/persist"`


#### `myModules.system.impermanence.rollback.blankSnapshot`

**Description**: Name of the read-only blank root snapshot
- **Type**: `string`
- **Default**: `"@root-blank"`


#### `myModules.system.impermanence.rollback.enable`

**Description**: Enable initrd rollback service that erases root on every boot
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.impermanence.rollback.rootSubvolume`

**Description**: Name of the root BTRFS subvolume
- **Type**: `string`
- **Default**: `"@"`


#### `myModules.system.nix.enable`

**Description**: Whether to enable Nix daemon configuration and settings.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.system.packages.android`

**Description**: Android device connectivity (adb, fastboot)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.packages.base`

**Description**: Base system utilities (wget, curl, jq, tree, zip, etc.)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.packages.benchmarking`

**Description**: Benchmarking and stress-testing tools
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.system.packages.dev`

**Description**: Developer CLI tools (nil, sherlock)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.packages.diagnostics`

**Description**: System diagnostics tools
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.packages.editors`

**Description**: Terminal text editors (vim, nano)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.packages.enable`

**Description**: Whether to enable System packages.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.system.packages.hardware`

**Description**: Hardware inspection and monitoring tools
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.packages.ios`

**Description**: iOS device connectivity (libimobiledevice, ifuse)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.packages.media`

**Description**: Media processing tools (ffmpeg)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.packages.monitoring`

**Description**: GPU and system monitoring tools
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.packages.networking`

**Description**: Network filesystem and tools (samba, cifs-utils, iproute2)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.services.acpid`

**Description**: ACPI event daemon
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.services.earlyoom.enable`

**Description**: Early OOM killer (prevents system freezes)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.services.earlyoom.freeMemThreshold`

**Description**: Minimum free memory percentage before killing
- **Type**: `signed integer`
- **Default**: `5`


#### `myModules.system.services.earlyoom.freeSwapThreshold`

**Description**: Minimum free swap percentage before killing
- **Type**: `signed integer`
- **Default**: `10`


#### `myModules.system.services.enable`

**Description**: Whether to enable Common system services.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.system.services.fstrim.enable`

**Description**: Periodic SSD TRIM
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.services.fstrim.interval`

**Description**: How often to run fstrim
- **Type**: `string`
- **Default**: `"weekly"`


#### `myModules.system.services.geoclue`

**Description**: GeoClue2 location service
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.system.services.printing`

**Description**: Printing support (CUPS)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.services.upower`

**Description**: UPower (battery/power monitoring)
- **Type**: `boolean`
- **Default**: `true`


#### `myModules.system.services.usbmuxd`

**Description**: USB multiplexing daemon (iOS device support)
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.system.users.enable`

**Description**: Whether to enable User configuration.
- **Type**: `boolean`
- **Default**: `false`



## TOOLS (2 options)

#### `myModules.tools.iommu`

**Description**: Whether to enable IOMMU group listing tool.
- **Type**: `boolean`
- **Default**: `false`


#### `myModules.tools.sysdiag`

**Description**: Whether to enable sysdiag system diagnostics.
- **Type**: `boolean`
- **Default**: `false`



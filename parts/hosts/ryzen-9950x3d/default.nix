{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # ============================================================================
  # MyModules Configuration — Exhaustive Reference
  # ============================================================================
  # Every myModules option is listed explicitly, even defaults, so this file
  # serves as a display config showing all available knobs. Options using their
  # module default are marked with # (default).
  # ============================================================================
  myModules = {

    # --------------------------------------------------------------------------
    # Primary User
    # --------------------------------------------------------------------------
    # primaryUser = "user"; # (default)

    # --------------------------------------------------------------------------
    # System
    # --------------------------------------------------------------------------
    system = {
      nix.enable = true;
      users.enable = true;

      services = {
        enable = true;
        printing = true; # (default)
        fstrim = {
          enable = true; # (default)
          interval = "weekly"; # (default)
        };
        earlyoom = {
          enable = true; # (default)
          freeMemThreshold = 5; # (default)
          freeSwapThreshold = 10; # (default)
        };
        acpid = true; # (default)
        upower = true; # (default)
        geoclue = true; # Night light location
        usbmuxd = true; # iOS device support
      };

      filesystems = {
        enable = true;
        enableAll = true; # (default) — enables all filesystem categories below
        enableLinux = true; # (default)
        enableWindows = true; # (default)
        enableMac = true; # (default)
        enableOptical = true; # (default)
        enableLegacy = false; # (default)
      };

      packages = {
        enable = true;
        base = true; # (default) — wget, curl, jq, tree, zip, etc.
        networking = true; # (default) — samba, cifs-utils, iproute2
        android = true; # (default) — adb, fastboot
        ios = true; # (default) — libimobiledevice, ifuse
        dev = true; # (default) — nil, sherlock
        media = true; # (default) — ffmpeg
        editors = true; # (default) — vim, nano
        hardware = true; # (default) — pciutils, usbutils, lshw, etc.
        diagnostics = true; # (default) — inxi, ethtool, powertop, etc.
        monitoring = true; # (default) — lact, radeontop (AMD-conditional)
        benchmarking = true; # Off by default — enable for stress-testing workstation
      };

      boot = {
        enable = true;
        loader = "systemd-boot"; # (default)
        secureBoot = {
          enable = true;
          # pkiBundle = "/var/lib/sbctl"; # (default)
        };
        plymouth = {
          enable = true;
          # theme uses module default
        };
        initrd.enable = true; # Systemd initrd (faster boot, needed for impermanence rollback)
        # consoleMode uses module default
      };

      # Impermanence — disabled until @persist + @root-blank subvolumes are created
      # See docs/installation.md for setup steps
      impermanence = {
        enable = false;
        # persistPath = "/persist"; # (default)
        # luksDevice = "cryptroot"; # (default)
        # rollback.enable = true; # (default)
        # rollback.blankSnapshot = "@root-blank"; # (default)
      };

      kernel = {
        enable = true;
        variant = "cachyos-lto";
        # channel = "latest"; # (default)
        mArch = "ZEN5"; # Zen 5 (9950X3D) supports x86-64-v4, use ZEN4 for specific tuning
        extraParams = [
          # loglevel=0 removed — Plymouth/Lanzaboote appends loglevel=4 which overrides it
          "vt.global_cursor_default=0"
          "iommu=pt"
          "nowatchdog"
          "acpi_enforce_resources=lax"
          "pci=realloc"
          "usbcore.autosuspend=-1" # Disable USB autosuspend (fixes xhci_hcd suspend timeout)
          "split_lock_detect=off" # Prevents perf drops in games using split-lock instructions
          "nvme_core.default_ps_max_latency_us=0" # Disable NVMe power state transitions (prevents micro-stutters)
          "tsc=reliable" # Pin TSC as clocksource — Zen 5 has invariant TSC
        ];
        cachyos = {
          cpusched = "bore"; # BORE compiled into kernel as fallback; scx_lavd overlays it via BPF when loaded
          bbr3 = true;
          hzTicks = "1000";
          kcfi = false;
          performanceGovernor = false; # powersave governor via P-State active mode is correct for Zen 5
          tickrate = "full";
          preemptType = "full";
          ccHarder = true;
          hugepage = "always";
        };
      };
    };

    # --------------------------------------------------------------------------
    # Security
    # --------------------------------------------------------------------------
    security = {
      hardening = {
        enable = true;
        firejail.enable = false; # Not needed — Portmaster handles app isolation
      };
      ssh = {
        enable = true;
        trustedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmK9yl3ndTzn5Qt42njlROMMf2LzOCjwzQwob1mrP9p user@ryzen-9950x3d"
        ];
        fail2banIgnoreIPs = [
          "127.0.0.1/8"
          "::1/128"
          "192.168.0.0/16"
        ];
      };
      sops = {
        enable = true;
        # defaultSopsFile and ageKeyFile use module defaults
      };
      portmaster = {
        enable = true;
        notifier = true; # System tray icon (autostart)
        autostart = true; # Start on boot
      };
      arkenfox = {
        enable = true;
        targetDir = "/home/${config.myModules.primaryUser}/.var/app/io.gitlab.librewolf-community/.librewolf/ulnbwvmb.default";
      };
    };

    # --------------------------------------------------------------------------
    # Hardware
    # --------------------------------------------------------------------------
    hardware = {
      core.enable = true;
      networking = {
        enable = true;
        # openPorts = []; # (default)
        # openPortRanges = []; # (default)
        # nameservers use module default
      };
      audio = {
        enable = true;
        pipewire.lowLatency = true;
        easyeffects.enable = false; # GoXLR handles all audio processing
      };
      bluetooth = {
        enable = true;
        powerOnBoot = true;
      };
      graphics = {
        enable = true;
        enable32Bit = true; # (default)
        # Intel GPU: not imported on this host (see flake-module.nix)
        # NVIDIA GPU: not imported on this host (see flake-module.nix)
        # openCL.rusticlDrivers assembled automatically from GPU modules
        mesaGit = {
          enable = true; # Bleeding-edge Mesa from git main (RDNA 4 optimizations)
          drivers = [ "amd" ]; # Only compile AMD drivers (radeonsi, RADV) + essentials
        };
      };
      gpu.amd = {
        enable = true;
        vulkanDeviceId = "1002:7550"; # RX 9070 XT — force dGPU for Vulkan on dual-AMD systems
        vulkanDeviceName = "AMD Radeon RX 9070 XT"; # Substring match for DXVK/VKD3D device filter
        lact.enable = true;
        initrd.enable = true; # Load amdgpu early (faster display init)
        enablePPFeatureMask = true; # Full power management feature flags
        rdna4Fixes = true; # RDNA 4 stability kernel params
        drmDebug = false; # Was destroying ALL boot logs (~800 msg/sec overflows kmsg ring buffer)
        disableHDCP = false; # HDCP enabled (was disabled for RDNA 4 handshake debugging)
        openCL = true; # (default) — RustiCL radeonsi driver
      };
      cpu.amd = {
        enable = true; # AMD CPU optimizations (pstate, prefcore, kvm, microcode)
        pstate = {
          enable = true; # (default)
          mode = "active"; # (default)
        };
        prefcore.enable = true; # (default)
        x3dVcache = {
          enable = true; # Dual-CCD 3D V-Cache optimizer (works at CPPC firmware level — scheduler-independent)
          mode = "cache"; # Prefer CCD0 (96MB 3D V-Cache) for gaming
        };
        kvm.enable = true; # (default) — KVM virtualization
        updateMicrocode = true; # (default)
        zenpower = true; # zenpower5 — Zen 5 Granite Ridge temps + RAPL power (replaces k10temp)
        ryzenSmu = true; # SMU access for runtime CO read/write, PBO limits, boost override
      };
      sensors = {
        nct6775 = true; # Nuvoton NCT6799 Super I/O — motherboard Vcore, fan speeds, temperatures
        # it87 = false; # (default) — ITE Super I/O for Gigabyte boards
      };
      # Intel CPU: not imported on this host (see flake-module.nix)
      performance = {
        enable = true;
        # amd_pstate active + "powersave" governor: CPU still boosts to max under load.
        # "powersave" just lets firmware scale dynamically via EPP — does NOT cap frequency.
        # "performance" would waste 20-40W at idle for negligible gaming benefit.
        governor = "powersave";
        # CachyOS wiki warns ananicy-cpp can conflict with sched-ext schedulers:
        # it amplifies priority gaps, potentially starving tasks and triggering the
        # scx watchdog timeout. Disable if you see stalls; scx_lavd handles priority itself.
        ananicy = true;
        irqbalance = false; # Not needed — scx_lavd handles core affinity
        scx = {
          enable = true;
          scheduler = "scx_lavd"; # Latency-aware virtual deadline (Valve/Steam Deck/Meta choice)
          extraArgs = [ "--performance" ]; # Static performance mode (no autopilot)
          # With power-profiles-daemon disabled, autopilot can't be toggled dynamically.
          # Use --performance for consistent low-latency gaming. Trade-off: higher idle power.
        };
        # Scheduler stack (no conflicts — each operates at a different layer):
        #   Layer 1: amd_3d_vcache mode=cache → firmware CCD routing (prefer V-Cache CCD0)
        #   Layer 2: amd_pstate active + powersave → firmware CPPC frequency scaling via EPP
        #   Layer 3: BORE (CFS-based, compiled into CachyOS kernel) → kernel scheduler fallback
        #   Layer 4: scx_lavd (BPF overlay) → takes over scheduling when loaded, BORE is fallback
        #   Layer 5: ananicy-cpp → process nice/ionice rules (may conflict with Layer 4)
      };
      power = {
        enable = true;
        profile = "balanced"; # Profile label only — actual governor set by performance module ("powersave")
        laptop = false; # Not a laptop — no TLP
      };
      # MacBook: not imported on this host (see flake-module.nix)
    };

    # --------------------------------------------------------------------------
    # Input
    # --------------------------------------------------------------------------
    input = {
      yeetmouse = {
        enable = true;
        devices.g502 = {
          enable = true; # Libinput flat profile HWDB entries (prevents double acceleration)
          # Acceleration parameters are set via hardware.yeetmouse below
        };
      };
      duckyOneXMini.enable = true;
      piper.enable = true;
      streamcontroller.enable = true;
    };
    coolercontrol.enable = true; # Fan/cooling device management (daemon + GUI)

    # --------------------------------------------------------------------------
    # Desktop
    # --------------------------------------------------------------------------
    desktop = {
      kde = {
        enable = true;
        xkbLayout = "us"; # (default)
        xkbVariant = ""; # (default)
        ddcBrightness = true; # DDC/CI brightness control via i2c-dev (PowerDevil)
      };
      flatpak.enable = true;
      displays = {
        enable = true;
        phantomUuids = [ "a460df66-ee57-4a8f-ba9b-4a877908e962" ];
        monitors = {
          main = {
            connector = "DP-1";
            mode = {
              width = 1920;
              height = 1080;
              refreshRate = 239757;
            };
            position = {
              x = 0;
              y = 127;
            };
            priority = 1;
            vrr = "automatic";
            edidHash = "9f311191c8a8ef17808acd6e824be682";
            edidIdentifier = "DEL 41313 811028053 18 2021 0";
            uuid = "3527f744-8931-4a23-a80e-55a2c9ec0fbe";
            tiling.layout = ''{"layoutDirection":"horizontal","tiles":[{"width":0.5},{"width":0.5}]}'';
          };
          portrait = {
            connector = "DP-2";
            mode = {
              width = 1920;
              height = 1080;
              refreshRate = 239761;
            };
            position = {
              x = 1920;
              y = 0;
            };
            priority = 2;
            rotation = "right";
            vrr = "automatic";
            edidHash = "32829c0ae88c33a9e3a9f349597d76af";
            edidIdentifier = "DEL 41219 810371157 26 2017 0";
            uuid = "069d4759-61df-4d8b-809e-cbb11fb33857";
            tiling.layout = ''{"layoutDirection":"vertical","tiles":[{"height":0.333},{"height":0.334},{"height":0.333}]}'';
          };
          crt = {
            connector = "HDMI-A-1"; # GPU HDMI
            alternateConnectors = [ "HDMI-A-3" ]; # Motherboard HDMI (fallback)
            mode = {
              width = 1280;
              height = 1024;
              refreshRate = 75025;
            };
            position = {
              x = 0;
              y = 183;
            };
            priority = 3;
            enabled = false;
            vrr = "never";
            uuid = "6b146127-4137-452c-a823-3f9b7ef75b14"; # CRT EDID-derived UUID (stable across ports)
            alternateUuids = [ "c808e708-83c0-4558-b83c-62dc0cae958f" ]; # Old kscreen UUID (stale)
            tiling.layout = ''{"layoutDirection":"horizontal","tiles":[{"width":1.0}]}'';
            toggle = {
              enable = true;
              scriptName = "crt-toggle";
              repositions."DP-1" = {
                x = 1280;
                y = 127;
              };
              repositions."DP-2" = {
                x = 3200;
                y = 0;
              };
            };
          };
        };
      };
    };

    # --------------------------------------------------------------------------
    # TidalCycles
    # --------------------------------------------------------------------------
    tidalcycles = {
      enable = true;
      autostartSuperDirt = false;
    };

    # --------------------------------------------------------------------------
    # GoXLR
    # --------------------------------------------------------------------------
    goxlr = {
      enable = true;
      isMini = false; # (default) — full-size GoXLR
      utility.enable = true; # (default)
      installProfiles = true; # (default)
      eq = {
        enable = true;
        clearStreamProperties = true; # (default)
        channels = {
          system.eq = config.myModules.goxlr.eq.presets.dt990pro;
          game.eq = config.myModules.goxlr.eq.presets.dt990pro;
          chat.eq = config.myModules.goxlr.eq.presets.dt990pro;
          music.eq = config.myModules.goxlr.eq.presets.dt990pro;
          sample.eq = config.myModules.goxlr.eq.presets.dt990pro;
        };
      };
      denoise = {
        enable = true;
        # Condenser mic ~40cm away: reduce aggression to prevent voice cutoff
        attenuationLimit = 12; # Light suppression (default 100 = unlimited, way too aggressive)
        minThreshold = -10.0; # Don't process very quiet signals as noise (default -15)
        maxErbThreshold = 10.0; # Lower = less muffling on speech (default 20)
        maxDfThreshold = 8.0; # Lower = preserve keyboard/transient sounds more (default 12)
      };
      toggle = {
        enable = true;
        activeProfile = "Yellow Default";
        activeMicProfile = "Mic NeatKingBee";
      };
    };

    # --------------------------------------------------------------------------
    # Development
    # --------------------------------------------------------------------------
    development = {
      enable = true;
      claudeCode = true;
      saleae = true;
      debuggingProbes.enable = true;
    };

    # --------------------------------------------------------------------------
    # Diagnostics
    # --------------------------------------------------------------------------
    diagnostics = {
      sysdiag.enable = true;
      iommu.enable = true;
      corecycler = {
        enable = true; # CoreCyclerLx — per-core CPU stability tester + PBO Curve Optimizer tuner
        unfreeBackends = true; # Include mprime (unfree) alongside stress-ng
        # Kernel modules (ryzen_smu, zenpower, nct6775) are in hardware.cpu.amd and hardware.sensors
      };
    };

    # --------------------------------------------------------------------------
    # VFIO — Stealth GPU Passthrough
    # --------------------------------------------------------------------------
    vfio = {
      enable = true;
      bindMethod = "dynamic"; # Libvirt hooks bind/unbind on VM start/stop
      stealth = {
        enable = true; # Patched QEMU + KVM RDTSC spoofing
        smbios = {
          manufacturer = "ASUSTeK COMPUTER INC.";
          product = "ROG CROSSHAIR X870E HERO";
          biosVendor = "American Megatrends Inc.";
          biosVersion = "2101";
        };
      };
      lookingGlass = {
        enable = true;
        memoryMB = 32; # 1080p SDR (15MB/frame × 2 = 30MB, 32MB is next power of 2)
      };
      hugepages = {
        enable = true;
        count = 32; # 32 × 1GB = 32GB for VM (1GB pages = fewer TLB misses than 2MB)
        size = "1G"; # 1GB hugepages for maximum gaming performance
      };
      evdev = {
        enable = true;
        keyboardPath = "/dev/input/by-id/usb-Ducky_Ducky_One_X_Mini_Wireless-event-kbd";
        mousePath = "/dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-mouse";
        # Toggle host/guest: press both Ctrl keys simultaneously (grab_all=on)
      };
      # Windows 11 Gaming VM
      # GPU passthrough: RX 9070 XT drives all 3 monitors (DP-1, DP-2, HDMI-A-1)
      # When VM starts: all monitors on the 9070 XT switch to Windows automatically
      # When VM stops: GPU returns to host, monitors show Linux again
      # Host management while VM runs: SSH, or plug a monitor into motherboard HDMI-A-3 (iGPU)
      # Looking Glass: view VM output on iGPU display without separate monitor
      vms.win11 = {
        uuid = "f298e20c-32ad-4921-87f0-164a211125c9";
        memory.count = 32;
        vcpu = {
          count = 16;
          # CCD0 (V-Cache, 96MB L3) — maximum gaming performance
          # Physical cores 0-7 + SMT threads 16-23 share the 96MB L3 cache
          # CCD1 (cores 8-15, 24-31) stays for host background tasks
          pinning = [
            0
            1
            2
            3
            4
            5
            6
            7
            16
            17
            18
            19
            20
            21
            22
            23
          ];
        };
        # NVMe passthrough: Windows NVMe controller at 05:00.0 (IOMMU Group 19, isolated)
        # Windows sees its real Samsung 9100 PRO — existing install boots directly
        pciPassthrough = [ "0000:05:00.0" ]; # Samsung 9100 PRO 2TB (Windows NVMe)
        gpu = {
          pciAddress = "0000:03:00.0"; # RX 9070 XT VGA (IOMMU Group 16)
          audioAddress = "0000:03:00.1"; # RX 9070 XT Audio (IOMMU Group 17)
        };
        # CCD0 = 8c/16t with 96MB V-Cache → spoof as Ryzen 7 9850X3D
        cpuIdentity = {
          modelId = "AMD Ryzen 7 9850X3D 8-Core Processor";
          maxSpeed = 5600; # 9850X3D boost clock
          currentSpeed = 4700; # 9850X3D base clock
        };
      };
    };

    # --------------------------------------------------------------------------
    # CachyOS Settings
    # --------------------------------------------------------------------------
    system.cachyos = {
      enable = true;
      zram.enable = true; # (default)
      ioSchedulers.enable = true; # (default)
      audio.enable = true; # (default)
      storage.enable = true; # (default)
      thp.enable = true; # (default)
      systemd.enable = true; # (default)
      timesyncd.enable = true; # (default)
      networkManager.enable = true; # (default)
      ntsync.enable = true; # (default)
      debuginfod.enable = true; # (default)
      coredump.enable = true; # (default)
      nvidia.enable = false; # (default) — no NVIDIA GPU
      amdgpuGcnCompat.enable = false; # Not needed for RX 9070 XT (RDNA 4)
      extraPerformance.enable = true; # (default)
    };
  };

  # ============================================================================
  # Gaming Configuration
  # ============================================================================
  myModules.gaming = {
    enable = true;
    steam = {
      enable = true; # (default)
      gamescope = true; # (default)
    };
    protonplus.enable = true;
    heroic.enable = true; # (default)
    gamescope.enable = false; # Standalone gamescope — use Steam's built-in instead
    mangohud.enable = false; # MangoHud — disabled, use vkBasalt overlay instead
    ryubing.enable = true; # Nintendo Switch emulator (Ryujinx fork)
    eden.enable = true; # Nintendo Switch emulator (community fork)
    azahar.enable = true; # 3DS emulator (Citra fork)
    nxSaveSync.enable = false; # Switch save sync tool
    occt.enable = true; # Stability Test & Benchmark
    lsfgVk.enable = true; # Vulkan frame generation (Lossless Scaling)
    prismlauncher.enable = true; # Minecraft Launcher
    gpuDevice = 1; # RX 9070 XT = card1 (gpu1 in btop)
    gamemode = {
      renice = 0; # Disabled — ananicy-cpp handles process priorities globally
      ioprio = "off"; # Disabled — ananicy-cpp manages IO priority
      desiredgov = "performance"; # EPP hint: powersave→performance (modest boost on amd_pstate active)
      x3dMode = {
        desired = "cache"; # Gaming: prefer V-Cache CCD0 (96MB L3)
        default = "frequency"; # Non-gaming: prefer high-clock CCD1
      };
      pinCores = "yes"; # Auto-detect and pin game to V-Cache CCD
      gpuPerformanceLevel = "high"; # Force RX 9070 XT to max clocks during gaming
    };
    radv.perftest = ""; # No extra RADV_PERFTEST flags needed on RDNA 4
    packages = {
      performance = true; # (default)
      cachyos = true; # (default)
    };
    # vkBasalt overlay: CAS sharpening + Vibrance + subtle color grading
    # Safe post-processing — no memory injection, no anti-cheat risk
    # Enable per-game: vkbasalt-run %command% (or ENABLE_VKBASALT=1)
    # In-game: F1 opens overlay UI, Home toggles effects
    # Per-game configs are managed live through the overlay UI
    vkbasalt = {
      enable = true; # (default)
      toggleKey = "Pause";
      overlayKey = "F1"; # (default)
      effects = "cas:Vibrance:LiftGammaGain";
      casSharpness = "0.5";
      enableOnLaunch = true; # (default)
      autoApply = true; # (default)
      extraConfig = ''
        # Vibrance — saturation boost (like VibranceGUI on Windows)
        Vibrance = 0.35

        # LiftGammaGain — color grading (R,G,B,brightness; 1.0 = neutral)
        LiftGammaGainLift = 1.0,1.0,1.0,1.02
        LiftGammaGainGamma = 1.0,1.0,1.0,0.98
        LiftGammaGainGain = 1.0,1.0,1.0,1.03
      '';
    };
    wine = {
      enable = true;
      variant = "staging";
      bottles.enable = true;
    };
  };

  # ============================================================================
  # System & Localization
  # ============================================================================
  system.stateVersion = "26.05";

  networking.hostName = "ryzen-9950x3d";
  time.timeZone = "Europe/Berlin";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "de_DE.UTF-8/UTF-8"
    ];
    extraLocaleSettings = {
      LC_MEASUREMENT = "de_DE.UTF-8";
      LC_MONETARY = "de_DE.UTF-8";
      LC_NUMERIC = "de_DE.UTF-8";
      LC_PAPER = "de_DE.UTF-8";
      LC_TIME = "de_DE.UTF-8";
    };
  };

  # ============================================================================
  # Boot Configuration
  # ============================================================================
  boot = {
    # Note: btrfs already handled by filesystems.nix (enableAll)
    # Note: AMD kernel modules (amdgpu, kvm-amd, zenpower/k10temp, ryzen_smu) in cpu-amd.nix / gpu-amd.nix
    # Note: Super I/O (nct6775/it87) in hardware.sensors
    #
    # NCT6799 Super I/O fan header mapping (ASUS ROG Crosshair X870E Hero):
    #   fan1 / pwm1  = CPU_FAN   → Arctic Liquid Freezer III radiator fans (~1036 RPM)
    #   fan2 / pwm2  = CPU_OPT   → Empty
    #   fan3 / pwm3  = CHA_FAN1  → Chassis fan (~1333 RPM)
    #   fan4 / pwm4  = CHA_FAN2  → Chassis fan (~1309 RPM)
    #   fan5 / pwm5  = CHA_FAN3  → Chassis fan (~1041 RPM)
    #   fan6 / pwm6  = CHA_FAN4  → Empty
    #   fan7 / pwm7  = W_PUMP+   → Arctic Liquid Freezer III pump (~2789 RPM, always full)
    #   (VRM contact frame fan is SATA-powered — not visible to hwmon)
    loader.timeout = lib.mkForce 10;
    blacklistedKernelModules = [
      "acpi_pad" # Forces CPU idle states — counterproductive on performance desktop
      "mac_hid" # macOS HID emulation — not needed
      "mousedev" # Legacy mouse device — not needed on Wayland
      "eeepc_wmi" # ASUS Eee PC WMI — loaded via ASUS WMI chain, not needed
    ];
  };

  # ============================================================================
  # YeetMouse Acceleration Settings
  # ============================================================================
  # Single source of truth for mouse acceleration parameters.
  # The upstream driver.nix applies these to sysfs via udev on any HID mouse connect.
  # G502 HWDB (flat libinput profile) is handled by myModules.yeetmouse.devices.g502.
  hardware.yeetmouse = {
    sensitivity = 0.5; # Match Raw Accel Windows (0.5)
    # sensitivity = 0.3125; # Match Raw Accel Windows (500/1600)
    rotation = {
      angle = 0.0;
    };
    mode.jump = {
      # acceleration = 1.5;
      # midpoint = 7.0
      acceleration = 2.0;
      midpoint = 7.8;
      useSmoothing = false;
      exponent = 0.00;
    };
  };

  # ============================================================================
  # Nix Daemon — 64GB RAM allows aggressive download buffering
  # ============================================================================
  nix.settings.download-buffer-size = 12 * 1024 * 1024 * 1024; # 12 GiB

  # ============================================================================
  # Filesystems
  # ============================================================================
  # Force tmpfs over any @tmp BTRFS subvolume from hardware-configuration.nix
  fileSystems."/tmp" = {
    device = lib.mkForce "tmpfs";
    fsType = lib.mkForce "tmpfs";
    options = lib.mkForce [
      "mode=1777"
      "noatime"
      "size=16G"
    ];
  };
}

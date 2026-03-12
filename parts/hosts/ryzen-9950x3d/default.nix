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
  # MyModules Configuration
  # ============================================================================
  myModules = {
    system = {
      nix = {
        enable = true;
      };
      users.enable = true;
      services = {
        enable = true;
        geoclue = true; # Night light location
        usbmuxd = true; # iOS device support
      };
      filesystems = {
        enable = true;
        enableAll = true;
      };
      packages = {
        enable = true;
        benchmarking = true; # Off by default — enable for stress-testing workstation
      };
    };

    security = {
      system = {
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

    hardware = {
      core.enable = true;
      networking.enable = true;
      audio = {
        enable = true;
        pipewire.lowLatency = true;

      };
      bluetooth = {
        enable = true;
        powerOnBoot = true;
      };
      graphics = {
        enable = true;
        amd = {
          enable = true;
          vulkanDeviceId = "1002:7550"; # RX 9070 XT — force dGPU for Vulkan on dual-AMD systems
          vulkanDeviceName = "AMD Radeon RX 9070 XT"; # Substring match for DXVK/VKD3D device filter
          lact.enable = true;
          initrd.enable = true; # Load amdgpu early (faster display init)
          enablePPFeatureMask = true; # Full power management feature flags
          rdna4Fixes = true; # RDNA 4 stability kernel params
          drmDebug = false; # Was destroying ALL boot logs (~800 msg/sec overflows kmsg ring buffer)
          disableHDCP = false; # HDCP enabled (was disabled for RDNA 4 handshake debugging)
        };
        enable32Bit = true;
        mesaGit = {
          enable = true; # Bleeding-edge Mesa from git main (RDNA 4 optimizations)
          drivers = [ "amd" ]; # Only compile AMD drivers (radeonsi, RADV) + essentials
        };
      };
      cpu.amd = {
        enable = true; # AMD CPU optimizations (pstate, prefcore, kvm, microcode)
        x3dVcache = {
          enable = true; # Dual-CCD 3D V-Cache optimizer (works at CPPC firmware level — scheduler-independent)
          mode = "cache"; # Prefer CCD0 (96MB 3D V-Cache) for gaming
        };
      };
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
      yeetmouse = {
        enable = true;
        devices.g502 = {
          enable = true; # Libinput flat profile HWDB entries (prevents double acceleration)
          # Acceleration parameters are set via hardware.yeetmouse below
        };
      };
      duckyOneXMini.enable = true;
      debuggingProbes.enable = true;
      piper.enable = true;
      streamcontroller = {
        enable = true;
      };
    };

    system.boot = {
      enable = true;
      loader = "systemd-boot";
      secureBoot = {
        enable = true;
        # pkiBundle uses default /var/lib/sbctl
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
    system.impermanence = {
      enable = false;
      # persistPath = "/persist";
      # luksDevice = "cryptroot";
      # rollback.enable = true;
      # rollback.blankSnapshot = "@root-blank";
    };

    desktop = {
      kde.enable = true;
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

    music = {
      tidalcycles = {
        enable = true;
        autostartSuperDirt = false;
      };
    };

    audio.goxlr = {
      enable = true;
      eq = {
        enable = true;
        channels = {
          system.eq = config.myModules.audio.goxlr.eq.presets.dt990pro;
          game.eq = config.myModules.audio.goxlr.eq.presets.dt990pro;
          chat.eq = config.myModules.audio.goxlr.eq.presets.dt990pro;
          music.eq = config.myModules.audio.goxlr.eq.presets.dt990pro;
          sample.eq = config.myModules.audio.goxlr.eq.presets.dt990pro;
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

    development = {
      enable = true;
      claudeCode = true;
      saleae = true;
    };

    tools = {
      sysdiag = true;
      iommu = true;
    };

    programs = {
      wine = {
        enable = true;
        variant = "staging";
      };
      bottles.enable = true;
    };

    kernel = {
      enable = true;
      variant = "cachyos-lto";
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

  # ============================================================================
  # Gaming Configuration
  # ============================================================================
  myModules.gaming = {
    enable = true;
    steam = {
      enable = true;
      gamescope = true;
    };
    protonplus.enable = true;
    heroic.enable = true;
    gamescope.enable = false; # Standalone gamescope — use Steam's built-in instead
    mangohud.enable = false; # MangoHud — disabled, use vkBasalt overlay instead
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
      performance = true;
      cachyos = true;
    };
    ryubing.enable = true; # Nintendo Switch emulator (Ryujinx fork)
    eden.enable = true; # Nintendo Switch emulator (community fork)
    azahar.enable = true; # 3DS emulator (Citra fork)
    nxSaveSync.enable = false; # Switch save sync tool
    occt.enable = true; # Stability Test & Benchmark
    lsfgVk.enable = true; # Vulkan frame generation (Lossless Scaling)
    prismlauncher.enable = true; # Minecraft Launcher
    # vkBasalt overlay: CAS sharpening + Vibrance + subtle color grading
    # Safe post-processing — no memory injection, no anti-cheat risk
    # Enable per-game: vkbasalt-run %command% (or ENABLE_VKBASALT=1)
    # In-game: F1 opens overlay UI, Home toggles effects
    # Per-game configs are managed live through the overlay UI
    vkbasalt = {
      enable = true; # vkBasalt Vulkan post-processing overlay
      toggleKey = "Pause";
      effects = "cas:Vibrance:LiftGammaGain";
      casSharpness = "0.5";
      extraConfig = ''
        # Vibrance — saturation boost (like VibranceGUI on Windows)
        Vibrance = 0.35

        # LiftGammaGain — color grading (R,G,B,brightness; 1.0 = neutral)
        LiftGammaGainLift = 1.0,1.0,1.0,1.02
        LiftGammaGainGamma = 1.0,1.0,1.0,0.98
        LiftGammaGainGain = 1.0,1.0,1.0,1.03
      '';
    };
  };

  # ============================================================================
  # CachyOS Settings
  # ============================================================================
  myModules.cachyos.settings = {
    enable = true;
    # All sub-options default to true except GPU-specific ones.
    # Only override what differs from defaults:
    amdgpuGcnCompat.enable = false; # Not needed for RX 9070 XT (RDNA 4)
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
    # Note: AMD kernel modules (amdgpu, kvm-amd, k10temp) in cpu-amd.nix / gpu-amd.nix
    loader.timeout = lib.mkForce 10;
    blacklistedKernelModules = [
      "acpi_pad" # Forces CPU idle states — counterproductive on performance desktop
      "mac_hid" # macOS HID emulation — not needed
      "mousedev" # Legacy mouse device — not needed on Wayland
      "eeepc_wmi" # ASUS Eee PC WMI — loaded via ASUS WMI chain, not needed
    ];
  };

  # ============================================================================
  # CPU Governor - now handled by cpu/amd.nix (schedutil default)
  # ============================================================================

  # power-profiles-daemon is disabled by myModules.hardware.power

  # ============================================================================
  # YeetMouse Acceleration Settings
  # ============================================================================
  # Single source of truth for mouse acceleration parameters.
  # The upstream driver.nix applies these to sysfs via udev on any HID mouse connect.
  # G502 HWDB (flat libinput profile) is handled by myModules.hardware.yeetmouse.devices.g502.
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

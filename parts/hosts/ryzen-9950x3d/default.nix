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
        geoclue = true;   # Night light location
        usbmuxd = true;   # iOS device support
      };
      filesystems = {
        enable = true;
        enableAll = true;
      };
      packages = {
        base = true;
        sync = true;
        dev = true;
        media = true;
        mobile = true;
        editors = true;
        hardware = true;
        diagnostics = true;
        monitoring = true;
        benchmarking = true;
      };
    };

    security = {
      system.enable = true;
      ssh = {
        enable = true;
        fail2banIgnoreIPs = [ "127.0.0.1/8" "::1/128" "192.168.0.0/16" ];
      };
      sops.enable = true;
      portmaster = {
        enable = true;
        notifier = true;  # System tray icon (autostart)
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
      graphics = {
        enable = true;
        amd = {
          enable = true;
          drmDebug = false; # Was destroying ALL boot logs (~800 msg/sec overflows kmsg ring buffer)
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
        governor = "powersave"; # Use powersave with EPP for Ryzen 9950X3D
        ananicy = true; # Use Ananicy CachyOS rules for process priority
        scx = {
          enable = true;
          scheduler = "scx_lavd"; # Latency-aware virtual deadline — best for gaming (Valve/Steam Deck choice)
          extraArgs = [ "--performance" ]; # Gaming mode: prioritize latency over power saving
        };
        # Scheduler stack: amd_3d_vcache (firmware CCD routing) → amd_pstate (CPPC preferred cores)
        #                   → BORE (kernel fallback) → scx_lavd (BPF overlay, takes precedence when loaded)
        # None of these conflict — CCD preference is set at hardware/firmware level.
      };
      power.enable = true;
      yeetmouse = {
        enable = true;
        devices.g502 = {
          enable = true; # Libinput flat profile HWDB entries (prevents double acceleration)
          # Acceleration parameters are set via hardware.yeetmouse below
        };
      };
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
        # pkiBundle = "/etc/secureboot"; # Removed to use default /var/lib/sbctl
      };
      plymouth.enable = true;
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
            mode = { width = 1920; height = 1080; refreshRate = 239757; };
            position = { x = 0; y = 127; };
            priority = 1;
            vrr = "automatic";
            edidHash = "9f311191c8a8ef17808acd6e824be682";
            edidIdentifier = "DEL 41313 811028053 18 2021 0";
            uuid = "3527f744-8931-4a23-a80e-55a2c9ec0fbe";
            tiling.layout = ''{"layoutDirection":"horizontal","tiles":[{"width":0.5},{"width":0.5,"layoutDirection":"vertical","tiles":[{"height":0.333},{"height":0.334},{"height":0.333}]}]}'';
          };
          portrait = {
            connector = "DP-2";
            mode = { width = 1920; height = 1080; refreshRate = 239761; };
            position = { x = 1920; y = 0; };
            priority = 2;
            rotation = "right";
            vrr = "automatic";
            edidHash = "32829c0ae88c33a9e3a9f349597d76af";
            edidIdentifier = "DEL 41219 810371157 26 2017 0";
            uuid = "069d4759-61df-4d8b-809e-cbb11fb33857";
            tiling.layout = ''{"layoutDirection":"vertical","tiles":[{"height":0.333},{"height":0.334},{"height":0.333}]}'';
          };
          crt = {
            connector = "HDMI-A-1";                       # GPU HDMI
            alternateConnectors = [ "HDMI-A-3" ];          # Motherboard HDMI
            mode = { width = 1280; height = 1024; refreshRate = 75025; };
            position = { x = 0; y = 183; };
            priority = 3;
            enabled = false;
            vrr = "never";
            uuid = "c808e708-83c0-4558-b83c-62dc0cae958f";         # GPU HDMI UUID
            alternateUuids = [ "6b146127-4137-452c-a823-3f9b7ef75b14" ]; # Motherboard HDMI UUID
            tiling.layout = ''{"layoutDirection":"horizontal","tiles":[{"width":1.0}]}'';
            toggle = {
              enable = true;
              scriptName = "crt-toggle";
              repositions."DP-1" = { x = 1280; y = 127; };
              repositions."DP-2" = { x = 3200; y = 0; };
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
      denoise.enable = true;
      toggle = {
        enable = true;
        activeProfile = "Yellow Default";
        activeMicProfile = "Mic NeatKingBee";
      };
    };

    development = {
      tools = {
        enable = true;
        helperScripts = true;
      };
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
        "usbcore.autosuspend=-1"                  # Disable USB autosuspend (fixes xhci_hcd suspend timeout)
        "split_lock_detect=off"                    # Prevents perf drops in games using split-lock instructions
        "nvme_core.default_ps_max_latency_us=0"    # Disable NVMe power state transitions (prevents micro-stutters)
        "tsc=reliable"                             # Pin TSC as clocksource — Zen 5 has invariant TSC
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
    gamescope.enable = false;
    mangohud.enable = false;
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
  };

  # ============================================================================
  # Tools Configuration
  # ============================================================================
  myModules.tools = {
    sysdiag.enable = true;        # System diagnostics (replaces list-gpu-drivers)
    listIommuGroups.enable = true; # IOMMU group listing
    llmPrep.enable = true;        # LLM context builder
    claudeCode.enable = true;     # Claude Code AI Assistant
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
      "acpi_pad"    # Forces CPU idle states — counterproductive on performance desktop
      "mac_hid"     # macOS HID emulation — not needed
      "mousedev"    # Legacy mouse device — not needed on Wayland
      "eeepc_wmi"   # ASUS Eee PC WMI — loaded via ASUS WMI chain, not needed
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
  nix.settings.download-buffer-size = 12 * 1024 * 1024 * 1024;  # 12 GiB

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

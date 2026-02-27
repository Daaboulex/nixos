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
      services.enable = true;
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
      };
      sops.enable = true;
      portmaster = {
        enable = true;
        ui.enable = true;
        notifier.enable = true;
      };
      arkenfox = {
        enable = true;
        targetDir = "/home/user/.var/app/io.gitlab.librewolf-community/.librewolf/ulnbwvmb.default";
        user = "user";
        group = "users";
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
        amd.enable = true;
        enable32Bit = true;
      };
      cpu.amd.enable = true; # AMD CPU optimizations (pstate, prefcore, kvm, microcode)
      performance = {
        enable = true;
        governor = "powersave"; # Use powersave with EPP for Ryzen 9950X3D
        ananicy = true; # Use Ananicy CachyOS rules for process priority
        scx = {
          enable = false;
          scheduler = "scx_rusty";
        };
      };
      power.enable = true;
      yeetmouse = {
        enable = true;
        devices.g502 = {
          enable = true;
          settings = {
            # sensitivity = 0.3125; # Match Raw Accel Windows (500/1600)
            # rotation = 0.0;
            # acceleration = 1.5;
            # midpoint = 7.0;
            sensitivity = 0.5; # Match Raw Accel Windows setting
            rotation = 0.0; # -1 degree
            acceleration = 2.0;
            midpoint = 7.8;
            useSmoothing = false;
            exponent = 0.00;
            accelerationModeNum = 7; # Jump mode
            preScale = 1.0;
            offset = 0.0;
            inputCap = 0.0;
            outputCap = 0.0;
          };
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
      kde = {
        enable = true;
        sddm = {
          primaryMonitor = "DP-1"; # Main monitor for login
          secondaryMonitor = "DP-2"; # Disable this for SDDM
        };
      };
      flatpak.enable = true;
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
          # Explicitly enable Beyerdynamic DT 990 Pro preset for all channels
          system.eq = config.myModules.audio.goxlr.eq.presets.dt990pro;
          game.eq = config.myModules.audio.goxlr.eq.presets.dt990pro;
          chat.eq = config.myModules.audio.goxlr.eq.presets.dt990pro;
          music.eq = config.myModules.audio.goxlr.eq.presets.dt990pro;
          sample.eq = config.myModules.audio.goxlr.eq.presets.dt990pro;
        };
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
      laptopSafe = false;
      preferLocalBuild = true; # Use binary cache when available
      mArch = "ZEN5"; # Zen 5 (9950X3D) supports x86-64-v4, use ZEN4 for specific tuning
      extraParams = [
        "loglevel=0"
        "vt.global_cursor_default=0"
        "iommu=pt"
        "nowatchdog"
        "acpi_enforce_resources=lax"
        "pci=realloc"
        "usbcore.autosuspend=-1" # Disable USB autosuspend (fixes xhci_hcd suspend timeout)
        "split_lock_detect=off"  # Prevents perf drops in games using split-lock instructions
      ];
      cachyos = {
        cpusched = "bore"; # Use built-in Bore scheduler instead of SCX BPF
        bbr3 = true;
        hzTicks = "1000";
        kcfi = false;
        performanceGovernor = true;
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
  };

  # ============================================================================
  # Tools Configuration
  # ============================================================================
  myModules.tools = {
    sysdiag.enable = true;        # System diagnostics (replaces list-gpu-drivers)
    listIommuGroups.enable = true; # IOMMU group listing
    llmPrep.enable = true;        # LLM context builder
  };

  # ============================================================================
  # CachyOS Settings
  # ============================================================================
  myModules.cachyos.settings = {
    enable = true;
    ioSchedulers = true;      # bfq=HDD, mq-deadline=SSD, none=NVMe
    pciLatency = true;        # Audio PCI latency optimization
    audioPowerSave = true;    # Disable snd-hda-intel power saving on AC
    hdparmTuning = true;      # HDD hdparm tuning (user has HDD)
    sataALPM = true;          # SATA max_performance (user has SATA)
    ntsync = true;            # Wine/Proton NT sync primitives
    amdgpuGcnCompat = true;  # Not needed for RX 9070 XT (RDNA 4)
    thp = true;               # THP defrag + khugepaged shrinker
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
  };

  # ============================================================================
  # CPU Governor - now handled by cpu/amd.nix (schedutil default)
  # ============================================================================

  # ============================================================================
  # Services
  # ============================================================================
  services = {
    power-profiles-daemon.enable = false;
  };

  # ============================================================================
  # Global YeetMouse Settings
  # ============================================================================
  # Required because driver.nix applies these settings to all mice via udev,
  # potentially overriding device-specific configs if not matched globally.
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
  # Filesystems
  # ============================================================================
  fileSystems."/tmp" = {
    fsType = "tmpfs";
    options = [
      "mode=1777"
      "noatime"
      "size=16G"
    ];
  };
}

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
      nix.enable = true;
      users.enable = true;
      services.enable = true;
      diagnostics.enable = true;
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
        benchmarking = true; # Skip stress tests on old hardware
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
      base.enable = true;
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
      };
      power.enable = true;
      yeetmouse = {
        enable = true;
        devices.g502 = {
          enable = true;
          settings = {
            sensitivity = 0.5; # Match Raw Accel Windows setting
            rotation = -0.01745; # -1 degree
            acceleration = 2.0;
            midpoint = 7.8;
            useSmoothing = false;
            accelerationModeNum = 7; # Jump mode
            preScale = 1.0;
            offset = 0.0;
            inputCap = 0.0;
            outputCap = 0.0;
          };
        };
      };
      streamcontroller = {
        enable = true;
      };
    };

    boot = {
      enable = true;
      loader = "systemd-boot";
      secureBoot = {
        enable = true;
        pkiBundle = "/etc/secureboot";
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
      antigravity = {
        enable = true;
        browser = "ungoogled-chromium";
      };
    };

    programs = {
      wine = {
        enable = true;
        variant = "staging";
      };
      bottles.enable = true;
    };

    chaotic.optimizations = {
      enable = true;
      enableSchedExt = true;
      schedExtScheduler = "scx_rusty"; # Best for gaming - minimizes latency/stuttering
    };

    

    chaotic.gaming = {
      enable = true;
      cpuMicroarch = "v4"; # 9950X3D is Zen 5, use v4 (x86-64-v4)
    };

    kernel = {
      enable = true;
      variant = "cachyos-lto";
      laptopSafe = false;
      preferLocalBuild = true; # Use binary cache when available
      mArch = "ZEN4"; # Zen 5 (9950X3D) supports x86-64-v4, use ZEN4 for specific tuning
      extraParams = [
        "loglevel=0"
        "vt.global_cursor_default=0"
        "iommu=pt"
        "nowatchdog"
        "acpi_enforce_resources=lax"
        "pci=realloc"
        "usbcore.autosuspend=-1" # Disable USB autosuspend (fixes xhci_hcd suspend timeout)
        
        # # AMD GPU Stabilization (Fix for ring timeout/crashes)
        # "amdgpu.ppfeaturemask=0xf7fff" # Disable GFXOFF
        # "amdgpu.runpm=0" # Disable Runtime Power Management
        # "amdgpu.aspm=0" # Disable Active State Power Management
      ];
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
  };

  # ============================================================================
  # Tools Configuration
  # ============================================================================
  myModules.tools = {
    listGpuDrivers.enable = true; # list-gpu-drivers tool
    listIommuGroups.enable = true; # list-iommu-groups tool
    llmPrep.enable = true; # llm-prep context tool
  };

  # ============================================================================
  # CachyOS Settings
  # ============================================================================
  myModules.cachyos.settings = {
    enable = true;
    allowUnsafe = true;
    applyAllConfigs = true;
    debug = true;
    categories = {
      desktop = true;
      networking = true;
      storage = true;
      gaming = true;
      server = true;
    };
    applyUdevIOSchedulers = true;
    applySATAALPM = true;
    applyTmpfilesTHP = true;
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
    supportedFilesystems = [ "btrfs" ];
    # Note: AMD kernel modules (amdgpu, kvm-amd, k10temp) now in amd.nix

    loader = {
      timeout = lib.mkForce 10;
    };
  };

  # ============================================================================
  # CPU Governor - now handled by cpu/amd.nix (schedutil default)
  # ============================================================================

  # ============================================================================
  # Services
  # ============================================================================
  services = {
    power-profiles-daemon.enable = false;

    fstrim = {
      enable = true;
      interval = "weekly";
    };
  };

  # ============================================================================
  # Global YeetMouse Settings
  # ============================================================================
  # Required because driver.nix applies these settings to all mice via udev,
  # potentially overriding device-specific configs if not matched globally.
  hardware.yeetmouse = {
    sensitivity = 0.5; # Match Raw Accel Windows (0.5)
    rotation = {
      angle = -1.0; # -1 degree
    };
    mode.jump = {
      acceleration = 2.0;
      midpoint = 7.8;
      useSmoothing = false;
      smoothness = 0.2;
    };
  };

  # ============================================================================
  # VPN Configuration
  # ============================================================================
  programs.hotspotshield.enable = true;

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

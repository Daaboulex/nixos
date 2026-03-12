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
  # serves as a display config showing all available knobs for this host.
  # Options using their module default are marked with # (default).
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
        printing = true; # (default) — MacBook often used with printers
        fstrim = {
          enable = true; # (default)
          interval = "weekly"; # (default)
        };
        earlyoom = {
          enable = true; # (default)
          freeMemThreshold = 5; # (default) — kill when <5% free RAM (16GB laptop)
          freeSwapThreshold = 10; # (default)
        };
        acpid = true; # (default) — ACPI event daemon (lid close, power button)
        upower = true; # (default) — battery monitoring
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
        monitoring = true; # (default) — GPU monitoring (Intel-conditional)
        benchmarking = false; # Skip stress tests on old laptop hardware
      };

      boot = {
        enable = true;
        loader = "systemd-boot"; # (default)
        # No Secure Boot on MacBook Pro 9,2 (2012 firmware doesn't support custom keys)
        secureBoot.enable = false;
        plymouth.enable = true;
        # initrd uses module default
      };

      # Impermanence — disabled, requires subvolumes
      impermanence.enable = false;
    };

    # --------------------------------------------------------------------------
    # Security
    # --------------------------------------------------------------------------
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
      sops.enable = true;
      portmaster = {
        enable = true;
        notifier = true; # (default) — system tray icon
        autostart = true; # Start on boot
      };
      arkenfox = {
        enable = true;
        # Update targetDir after first Librewolf launch on this machine
        targetDir = "/home/${config.myModules.primaryUser}/.var/app/io.gitlab.librewolf-community/.librewolf/default";
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
      };
      audio = {
        enable = true;
        pipewire.lowLatency = true;
        easyeffects.enable = false; # No audio processing needed
      };
      bluetooth = {
        enable = true;
        powerOnBoot = false; # Save power — enable on demand
      };
      graphics = {
        enable = true;
        enable32Bit = true; # (default)
        intel = {
          enable = true;
          kernelParams = {
            enablePsr = false; # PSR causes flickering on MBP 2012
            enableFbc = true; # Frame Buffer Compression for power saving
            enableDc = false; # Display C-states unstable on Ivy Bridge
          };
          openCL = true; # (default) — RustiCL iris driver
        };
        # AMD GPU: not imported on this host (see flake-module.nix)
        # NVIDIA GPU: not imported on this host (see flake-module.nix)
        # openCL.rusticlDrivers assembled automatically from GPU modules
        mesaGit.enable = false; # Standard mesa is fine for HD4000
      };
      cpu.intel = {
        enable = true;
        pstate = {
          enable = true; # (default)
          mode = "active"; # (default)
        };
        governor = "powersave"; # P-State powersave is efficient for Ivy Bridge
        kvm.enable = true; # (default) — virtualization (VT-x)
        updateMicrocode = true; # (default)
        iommu.enable = false; # No VT-d passthrough needed
      };
      # AMD CPU: not imported on this host (see flake-module.nix)
      performance = {
        enable = true;
        governor = "powersave"; # intel_pstate powersave — dynamic scaling, efficient for laptop
        ananicy = true; # CachyOS process prioritization rules
        irqbalance = true; # IRQ balancing — useful on 2C/4T to spread interrupts
        scx.enable = false; # sched-ext not beneficial on 2-core Ivy Bridge
      };
      power = {
        enable = true;
        profile = "balanced"; # (default)
        laptop = true; # Enable TLP for laptop power management
      };
    };

    # --------------------------------------------------------------------------
    # MacBook
    # --------------------------------------------------------------------------
    macbook = {
      patches.enable = lib.mkDefault false; # Disabled — specialisations override; see note below
      # Specialisation priority: this must be mkDefault so specialisations can set false
      # at normal priority. The "default" kernel variant may work with patches, but
      # xanmod/cachyos variants have different contexts that may not match.
      fan = {
        enable = true;
        lowTemp = 45; # Start ramping fan at 45 C
        highTemp = 65; # High fan speed at 65 C
        maxTemp = 80; # Maximum temperature
        pollingInterval = 1; # Check every second
      };
      touchpad = {
        enable = true;
        naturalScrolling = true; # (default)
        tapping = true; # (default) — tap-to-click
      };
      keyboard = {
        fnMode = 2; # Press fn for F-keys (default: media keys)
        swapOptCmd = true; # Cmd acts as Alt (standard PC layout)
      };
    };

    # --------------------------------------------------------------------------
    # Kernel
    # --------------------------------------------------------------------------
    kernel = {
      enable = true;
      variant = lib.mkDefault "default"; # Specialisations override to xanmod/cachyos
      channel = "latest"; # (default)
      mArch = "x86-64-v2"; # Ivy Bridge (SSE4.2, no AVX2)
      extraParams = [
        "vt.global_cursor_default=0" # Hide kernel text cursor
        "nowatchdog" # Disable watchdog (faster boot)
        "mem_sleep_default=deep" # S3 deep sleep (better battery on suspend)
        "acpi_enforce_resources=lax" # Allow ACPI resource access for sensors
      ];
      # cachyos sub-options only used when specialisation sets variant = "cachyos"
    };

    # --------------------------------------------------------------------------
    # Desktop
    # --------------------------------------------------------------------------
    desktop = {
      kde = {
        enable = true;
        xkbLayout = "us"; # (default)
        xkbVariant = ""; # (default)
        ddcBrightness = false; # (default)
      };
      flatpak.enable = true;
      # No displays module config — laptop uses built-in display only
    };

    # --------------------------------------------------------------------------
    # TidalCycles
    # --------------------------------------------------------------------------
    tidalcycles = {
      enable = true;
      autostartSuperDirt = false;
    };

    # --------------------------------------------------------------------------
    # Development
    # --------------------------------------------------------------------------
    development = {
      enable = true;
      claudeCode = true;
      saleae = false; # No Saleae hardware on laptop
    };

    # --------------------------------------------------------------------------
    # Tools & Programs
    # --------------------------------------------------------------------------
    sysdiag = true;
    iommu = false; # No IOMMU passthrough on this machine
    # corecycler: not imported on this host (AMD PBO CO tuner — Intel laptop)
    wine = {
      enable = true;
      variant = "staging";
    };
    bottles.enable = false; # Not needed on laptop

    # --------------------------------------------------------------------------
    # CachyOS Settings
    # --------------------------------------------------------------------------
    cachyos.settings = {
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
      amdgpuGcnCompat.enable = false; # Intel GPU, not AMD
      extraPerformance.enable = true; # (default)
    };

    # Gaming: not imported on this host (see flake-module.nix)
    # GoXLR: not imported on this host (see flake-module.nix)
  };

  # ============================================================================
  # System & Localization
  # ============================================================================
  system.stateVersion = "26.05";

  networking.hostName = "macbook-pro-9-2";
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
  # MacBook Pro 9,2 Hardware Fixes
  # ============================================================================
  hardware.enableRedistributableFirmware = true;

  boot = {
    loader.timeout = lib.mkForce 10;

    # Broadcom WiFi: blacklist conflicting drivers
    extraModprobeConfig = ''
      blacklist ssb
      blacklist bcma
    '';

    blacklistedKernelModules = [
      "iTCO_wdt" # Watchdog timer — not needed, causes errors
      "lpc_ich" # GPIO resource conflicts with ACPI OpRegion
      "acpi_pad" # Not needed on MacBook
      "mac_hid" # Old Mac HID emulation
    ];

    kernelParams = [
      # Broadcom / IOMMU fixes
      "intremap=off" # Suppress DMAR-IR firmware bug warnings
      "iommu=soft" # Fix USB 3.0 (xhci_hcd) on Ivy Bridge

      # SATA stability
      "libata.force=noncq" # Disable NCQ (stability on 2012 SATA)
      "libata.force=1.5Gbps" # Limit SATA speed to fix link errors

      # SD card reader fix
      "sdhci.debug_quirks2=4" # SDHCI_QUIRK2_NO_1_8_V

      # Security mitigations (SMT-aware, Spectre/Meltdown/MDS)
      "mds=full" # Full MDS mitigation
    ];

    # MacBook-specific kernel modules
    kernelModules = [
      "i915" # Intel HD4000 GPU
      "snd_hda_intel" # Audio codec
      "btusb" # Bluetooth USB
      "sdhci" # SD card reader
      "sdhci-pci" # SD card reader PCI bridge
    ];
  };

  # ============================================================================
  # Nix Daemon — Ivy Bridge i5 is 2C/4T, limit parallelism
  # ============================================================================
  nix.settings = {
    max-jobs = 4;
    cores = 4;
  };

  # Note: vm.swappiness, vm.dirty_*, vm.vfs_cache_pressure are all managed by
  # CachyOS settings (zram sets swappiness=150, dirty uses byte-based limits,
  # vfs_cache_pressure=50). No host-level overrides needed.

  # ============================================================================
  # Services
  # ============================================================================
  services = {
    gvfs.enable = true; # GVFS for Nautilus/Dolphin network browsing
    avahi = {
      enable = true; # mDNS for .local hostname resolution
      nssmdns4 = true;
    };

    # USB device power management fix (Broadcom WiFi adapter)
    udev.extraRules = lib.mkAfter ''
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", TEST=="power/control", ATTR{power/control}="on"
    '';
  };

  # ============================================================================
  # Filesystems
  # ============================================================================
  # Override the @tmp BTRFS subvolume from hardware-configuration.nix — RAM-backed
  # tmpfs is faster and avoids wearing the SSD with temporary file writes.
  fileSystems."/tmp" = {
    device = lib.mkForce "tmpfs";
    fsType = lib.mkForce "tmpfs";
    options = lib.mkForce [
      "mode=1777"
      "noatime"
      "size=8G" # Half of 16GB RAM
    ];
  };
}

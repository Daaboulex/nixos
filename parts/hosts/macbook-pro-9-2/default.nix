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
    # ------ System ------
    system = {
      nix.enable = true;
      users.enable = true;
      services = {
        enable = true;
        printing = true; # MacBook often used with printers
        fstrim.enable = true; # Periodic SSD TRIM (2x SSDs)
        earlyoom = {
          enable = true; # Kill memory hogs before system freezes (16GB laptop)
          freeMemThreshold = 5; # Kill when <5% free RAM
          freeSwapThreshold = 10;
        };
        geoclue = true; # Night light location
        usbmuxd = true; # iOS device support
        acpid = true; # ACPI event daemon (lid close, power button)
        upower = true; # Battery monitoring
      };
      filesystems = {
        enable = true;
        enableAll = true;
      };
      packages = {
        enable = true;
        benchmarking = false; # Skip stress tests on old laptop hardware
      };
      boot = {
        enable = true;
        loader = "systemd-boot";
        # No Secure Boot on MacBook Pro 9,2 (2012 firmware doesn't support custom keys)
        secureBoot.enable = false;
        plymouth.enable = true;
        # initrd uses module default
      };

      # Impermanence — disabled, requires subvolumes
      impermanence.enable = false;
    };

    # ------ Security ------
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
        notifier = true; # System tray icon
        autostart = true; # Start on boot
      };
      arkenfox = {
        enable = true;
        # Update targetDir after first Librewolf launch on this machine
        targetDir = "/home/${config.myModules.primaryUser}/.var/app/io.gitlab.librewolf-community/.librewolf/default";
      };
    };

    # ------ Hardware ------
    hardware = {
      core.enable = true;
      networking.enable = true;
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
        intel = {
          enable = true;
          kernelParams = {
            enablePsr = false; # PSR causes flickering on MBP 2012
            enableFbc = true; # Frame Buffer Compression for power saving
            enableDc = false; # Display C-states unstable on Ivy Bridge
          };
        };
        enable32Bit = true;
        mesaGit.enable = false; # Standard mesa is fine for HD4000
      };
      cpu.intel = {
        enable = true;
        pstate = {
          enable = true;
          mode = "active";
        };
        governor = "powersave"; # P-State powersave is efficient for Ivy Bridge
        kvm.enable = true; # Virtualization (VT-x)
        updateMicrocode = true; # Keep microcode current
        iommu.enable = false; # No VT-d passthrough needed
      };
      macbook = {
        patches.enable = lib.mkDefault false; # Disabled — specialisations override; see note below
        # Specialisation priority: this must be mkDefault so specialisations can set false
        # at normal priority. The "default" kernel variant may work with patches, but
        # xanmod/cachyos variants have different contexts that may not match.
        fan = {
          enable = true;
          lowTemp = 45; # Start ramping fan at 45°C
          highTemp = 65; # High fan speed at 65°C
          maxTemp = 80; # Maximum temperature
          pollingInterval = 1; # Check every second
        };
        touchpad = {
          enable = true;
          naturalScrolling = true;
          tapping = true; # Tap-to-click
        };
        keyboard = {
          fnMode = 2; # Press fn for F-keys (default: media keys)
          swapOptCmd = true; # Cmd acts as Alt (standard PC layout)
        };
      };
      performance = {
        enable = true;
        governor = "powersave"; # intel_pstate powersave — dynamic scaling, efficient for laptop
        ananicy = true; # CachyOS process prioritization rules
        irqbalance = true; # IRQ balancing — useful on 2C/4T to spread interrupts
        scx.enable = false; # sched-ext not beneficial on 2-core Ivy Bridge
      };
      power = {
        enable = true;
        profile = "balanced"; # Balanced power profile
        laptop = true; # Enable TLP for laptop power management
      };
    };

    # ------ Kernel ------
    kernel = {
      enable = true;
      variant = lib.mkDefault "default"; # Specialisations override to xanmod/cachyos
      channel = "latest"; # Latest stable kernel
      mArch = "x86-64-v2"; # Ivy Bridge (SSE4.2, no AVX2)
      extraParams = [
        "vt.global_cursor_default=0" # Hide kernel text cursor
        "nowatchdog" # Disable watchdog (faster boot)
        "mem_sleep_default=deep" # S3 deep sleep (better battery on suspend)
        "acpi_enforce_resources=lax" # Allow ACPI resource access for sensors
      ];
      # cachyos sub-options only used when specialisation sets variant = "cachyos"
    };

    # ------ Desktop ------
    desktop = {
      kde.enable = true;
      flatpak.enable = true;
      # No displays module config — laptop uses built-in display only
    };

    # ------ Programs ------
    programs = {
      wine = {
        enable = true;
        variant = "staging";
      };
      bottles.enable = false; # Not needed on laptop
    };

    # ------ Music ------
    music.tidalcycles = {
      enable = true;
      autostartSuperDirt = false;
    };

    # ------ Development ------
    development = {
      enable = true;
      claudeCode = true;
      saleae = false; # No Saleae hardware on laptop
    };

    # ------ Tools ------
    tools = {
      sysdiag = true;
      iommu = false; # No IOMMU passthrough on this machine
    };

    # ------ CachyOS Settings ------
    cachyos.settings = {
      enable = true;
      # All sub-options default to true. Override what doesn't apply:
      amdgpuGcnCompat.enable = false; # Intel GPU, not AMD
      nvidia.enable = false; # No Nvidia GPU
    };
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

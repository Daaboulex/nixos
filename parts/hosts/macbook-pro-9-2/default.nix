{ config, pkgs, inputs, lib, ... }:
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
        geoclue = true;       # Night light location
        usbmuxd = true;       # iOS device support
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
        benchmarking = false;  # Skip stress tests on old laptop hardware
      };
    };

    # ------ Security ------
    security = {
      system.enable = true;
      ssh = {
        enable = true;
        fail2banIgnoreIPs = [ "127.0.0.1/8" "::1/128" "192.168.0.0/16" ];
      };
      sops.enable = true;
      portmaster = {
        enable = true;
        notifier = true;
      };
      arkenfox = {
        enable = true;
        # Update targetDir after first Librewolf launch on this machine
        targetDir = "/home/${config.myModules.primaryUser}/.var/app/io.gitlab.librewolf-community/.librewolf/default";
      };
    };

    # ------ Boot ------
    system.boot = {
      enable = true;
      loader = "systemd-boot";
      # No Secure Boot on MacBook Pro 9,2 (2012 firmware doesn't support custom keys)
      secureBoot.enable = false;
      plymouth.enable = true;
    };

    # ------ Hardware ------
    hardware = {
      core.enable = true;
      networking.enable = true;
      audio = {
        enable = true;
        pipewire.lowLatency = true;
      };
      bluetooth = {
        enable = true;
        powerOnBoot = false;     # Save power, enable on demand
      };
      graphics = {
        enable = true;
        intel = {
          enable = true;
          kernelParams = {
            enablePsr = false;   # PSR causes flickering on MBP 2012
            enableFbc = true;    # Frame Buffer Compression for power saving
            enableDc = false;    # Display C-states unstable on Ivy Bridge
          };
        };
        enable32Bit = true;
        mesaGit.enable = false;  # Standard mesa is fine for HD4000
      };
      cpu.intel = {
        enable = true;
        pstate = {
          enable = true;
          mode = "active";
        };
        governor = "powersave";  # P-State powersave is efficient for Ivy Bridge
        kvm.enable = true;
        iommu.enable = false;    # No VT-d passthrough needed
      };
      macbook = {
        patches.enable = lib.mkDefault false;  # Disabled until tested on all kernel variants
        fan = {
          enable = true;
          lowTemp = 45;
          highTemp = 65;
          maxTemp = 80;
        };
        touchpad.enable = true;  # Natural scrolling, tap-to-click, clickfinger
        keyboard = {
          fnMode = 2;            # Press fn for F-keys (default: media keys)
          swapOptCmd = true;     # Cmd acts as Alt
        };
      };
      performance = {
        enable = true;
        governor = "powersave";
        ananicy = true;
        irqbalance = true;
        scx.enable = false;      # sched-ext not useful on older hardware
      };
      power = {
        enable = true;
        profile = "balanced";
        laptop = true;           # Enable TLP for laptop power management
      };
    };

    # ------ Kernel ------
    kernel = {
      enable = true;
      variant = lib.mkDefault "default";  # Specialisations override to xanmod/cachyos
      mArch = "x86-64-v2";               # Ivy Bridge (SSE4.2, no AVX2) — used by CachyOS variant
      extraParams = [
        "vt.global_cursor_default=0"
        "nowatchdog"
        "mem_sleep_default=deep"
        "acpi_enforce_resources=lax"
      ];
    };

    # ------ Desktop ------
    desktop = {
      kde.enable = true;
      flatpak.enable = true;
    };

    # ------ Programs ------
    programs.wine = {
      enable = true;
      variant = "staging";
    };

    # ------ Music ------
    music.tidalcycles = {
      enable = true;
      autostartSuperDirt = false;
    };

    # ------ Tools ------
    tools = {
      sysdiag.enable = true;
      listIommuGroups.enable = false;
      claudeCode.enable = true;
    };

    # ------ CachyOS Settings ------
    cachyos.settings = {
      enable = true;
      amdgpuGcnCompat.enable = false;
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
      "iTCO_wdt"     # Watchdog timer — not needed, causes errors
      "lpc_ich"      # GPIO resource conflicts with ACPI OpRegion
      "acpi_pad"     # Not needed on MacBook
      "mac_hid"      # Old Mac HID emulation
    ];

    kernelParams = [
      # Broadcom / IOMMU fixes
      "intremap=off"           # Suppress DMAR-IR firmware bug warnings
      "iommu=soft"             # Fix USB 3.0 (xhci_hcd) on Ivy Bridge

      # SATA stability
      "libata.force=noncq"     # Disable NCQ (stability on 2012 SATA)
      "libata.force=1.5Gbps"   # Limit SATA speed to fix link errors

      # SD card reader fix
      "sdhci.debug_quirks2=4"  # SDHCI_QUIRK2_NO_1_8_V

      # Security mitigations (SMT-aware)
      "mds=full"               # Full MDS mitigation
    ];

    # MacBook-specific kernel modules
    kernelModules = [
      "i915"
      "snd_hda_intel"
      "btusb"
      "sdhci"
      "sdhci-pci"
    ];
  };

  # ============================================================================
  # Speed Optimizations
  # ============================================================================

  # Nix build parallelism — Ivy Bridge i5 is 2C/4T
  nix.settings = {
    max-jobs = 4;
    cores = 4;
  };

  # Earlyoom — kill memory hogs before system freezes (16GB laptop)
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;      # Kill when <5% free RAM
    freeSwapThreshold = 10;
    enableNotifications = true;
  };

  # Note: vm.swappiness, vm.dirty_*, vm.vfs_cache_pressure are all managed by
  # CachyOS settings (zram sets swappiness=150, dirty uses byte-based limits,
  # vfs_cache_pressure=50). No host-level overrides needed.

  # ============================================================================
  # Services
  # ============================================================================
  services = {
    gvfs.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
    };
    printing.enable = true;       # MacBook often used with printers

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
      "size=8G"       # Half of 16GB RAM
    ];
  };
}

{ config, pkgs, inputs, lib, ... }:
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
        benchmarking = false; # Skip stress tests on old hardware
      };
    };

    security = {
      system.enable = true;
      ssh = {
        enable = true;
        trustedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBfUNW7YndM7IhlN+deDbI+3Oi/iqic5SmYQJgR+PUCV desktop-to-mac"
        ];
      };
      sops.enable = true;
      portmaster = {
        enable = true;
        ui.enable = true;
        notifier.enable = true;
      };
      arkenfox = {
        enable = true;
        targetDir = "/home/user/.var/app/io.gitlab.librewolf-community/.librewolf/ii745mt3.default";
        user = "user";
        group = "users";
      };
    };

    boot = {
      enable = true;
      loader = "systemd-boot";
    };

    hardware = {
      base.enable = true;
      networking.enable = true;
      audio.enable = true;
      graphics = {
        enable = true;
        intel.enable = true;
      };
      cpu.intel.enable = true;  # Intel CPU optimizations (pstate, kvm, microcode)
      performance = {
        enable = true;
        governor = "powersave"; # Efficient for Intel Ivy Bridge laptop
        zramPercent = 100;       # Balanced ZRAM use
      };
      power.enable = true;
      macbook.patches.enable = true;
      # yeetmouse.enable = true;
    };

    kernel = {
      enable = true;
      variant = "cachyos-lts"; # xanmod can be used instead if some items do not work
      laptopSafe = false;
      preferLocalBuild = false;
    };

    desktop = {
      kde.enable = true;
      flatpak.enable = true;
    };

    programs = {
      wine = {
        enable = true;
        variant = "staging";
      };
      bottles.enable = true;
    };

    music = {
      tidalcycles = {
        enable = true;
        autostartSuperDirt = false;
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

    # Chaotic-Nyx Package Optimizations
    # Ivy Bridge (MacBookPro9,2) supports x86-64-v2 (SSE4.2) but NOT x86-64-v3 (AVX2).
    # This module uses Chaotic packages which may be v3-optimized, but NixOS will fall back to standard builds if incompatible.
    chaotic.optimizations.enable = true;

    # virtualization = {
    #   libvirt.enable = true;
    #   vmware.enable = true;
    # };
  };

  # ============================================================================
  # CachyOS Settings
  # ============================================================================
  myModules.cachyos.settings = {
    enable = true;
    allowUnsafe = true;      # TESTING: Apply all CachyOS settings without filters
    applyAllConfigs = true;  # EXPERIMENTAL: Auto-discover ALL config files
    debug = true;            # Required for unsafe/experimental modes
    categories = {
      desktop = true;
      networking = true;
      storage = true;
      gaming = true;
      server = true;
    };
    
    # Previous granular settings (commented out while testing dynamic mode)
    # capJournald = true;
    # applyTmpfilesTHP = true;
    # x11TapToClick = true;
    # applyUdevIOSchedulers = false;
    # applySATAALPM = true;
  };

  # ============================================================================
  # System & Localization
  # ============================================================================
  system.stateVersion = "26.05";
  
  networking.hostName = "macbook-pro-9-2";
  time.timeZone = "Europe/Berlin";
  
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [ "en_US.UTF-8/UTF-8" "de_DE.UTF-8/UTF-8" ];
    extraLocaleSettings = { 
      LC_TIME = "de_DE.UTF-8"; 
    };
  };

  # Force correct locale environment variables to suppress perl warnings
  environment.variables = {
    LANG = "en_US.UTF-8";
    LC_TIME = "de_DE.UTF-8";
    # Explicitly unset invalid locales
    LC_NUMERIC = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_ADDRESS = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
  };

  # ============================================================================
  # Hardware & Boot Configuration
  # ============================================================================
  hardware = {
    enableRedistributableFirmware = true;
    intel.kernelParams = {
      enablePsr = false;
      enableFbc = true;
      enableDc = true;
    };
  };

  boot = {
    # Broadcom wireless configuration
    # options brcmfmac nohwcrypt=1 qos=0
    # Suppress b43 5GHz band warning (hardware limitation, not an error)
    # options b43 pio=0 qos=0
    extraModprobeConfig = ''
      blacklist b43
      blacklist ssb
      blacklist bcma
    '';
    
    blacklistedKernelModules = [ 
      "iTCO_wdt"   # Watchdog timer - not needed
      "lpc_ich"    # Causes GPIO resource conflicts with ACPI OpRegion
    ];

    # Additional kernel parameters for stability and security
    kernelParams = [
      "vt.global_cursor_default=0"
      "libata.force=noncq"
      #"irqpoll"
      "intremap=off"          # Suppress DMAR-IR firmware bug warnings
      "mem_sleep_default=deep"
      "intel_iommu=off"
      "intel_pstate=active"             # Use Intel P-State driver
      #"acpi_backlight=linux"  # Enable MacBook keyboard backlight
      "libata.force=1.5Gbps"         # Limit to SATA I speed to fix link errors
      "loglevel=7"                   # Slightly more verbose to catch errors
      "mds=full"                     # Full MDS mitigation (SMT enabled)
      "iommu=soft"                   # Fix USB 3.0 (xhci_hcd) on Ivy Bridge
      "sdhci.debug_quirks2=4"        # Fix SD Card (SDHCI_QUIRK2_NO_1_8_V)
    ];

    kernelModules = [
      "i2c_hid"        # If using I2C devices
      "at24"
      "i2c-dev"
      "hid_apple"      # Optional: for Apple-specific HID devices
      "hid_apple"      # Optional: for Apple-specific HID devices
      "coretemp"
      "i915"
      "snd_hda_intel"
      "btusb"
      "usbcore"
      "usb_storage"
      "sdhci"
      "sdhci-pci"
      "ehci_hcd"
      "ehci_pci"
      "xhci_hcd"
      "xhci_pci"
      "video"
    ];
  };

  # ============================================================================
  # Filesystems
  # ============================================================================
  fileSystems = {
    "/mnt/data" = {
      device = "/dev/disk/by-uuid/c20e54a0-638f-4d02-a1e6-8d23987b3046";
      fsType = "btrfs";
      options = [ "nofail" "rw" "compress=zstd" "autodefrag" ];
    };
    "/tmp" = {
      fsType = "tmpfs";
      options = [ "mode=1777" "noatime" ];
    };
  };

  # ============================================================================
  # Services
  # ============================================================================
  services = {
    gvfs.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
    };
    
    journald.extraConfig = ''
      Storage=persistent
      RuntimeMaxUse=256M
    '';

    mbpfan = {
      enable = true;
      verbose = false;
      settings.general = {
        low_temp = 45;
        high_temp = 65;
        max_temp = 80;
        polling_interval = 1;
      };
    };

    udev.extraRules = lib.mkAfter ''
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", TEST=="power/control", ATTR{power/control}="on"
    '';

    # Note: Flatpak packages now managed via Home Manager
  };
}
# Host: MacBook Pro 9,2 — laptop profile with open-source Broadcom
# Modules: system, security, hardware, graphics, desktop, virtualization, development

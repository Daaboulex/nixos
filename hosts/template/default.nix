{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ============================================================================
  # MyModules Configuration
  # ============================================================================
  # This section controls the custom modules defined in modules/
  # Enable/disable features as needed for this host.
  
  myModules = {
    # --------------------------------------------------------------------------
    # System Basics
    # --------------------------------------------------------------------------
    system = {
      nix.enable = true;          # Nix daemon settings (flakes, optimization, etc.)
      users.enable = true;        # User and group configuration
      services.enable = true;     # Common system services (fstrim, etc.)
      
      # Package collections to install
      packages = {
        base = true;              # Core utilities (git, vim, htop, etc.)
        dev = false;              # Development tools
        media = false;            # Media players and tools
        mobile = false;           # Mobile device tools (adb, etc.)
        editors = false;          # Extra editors (vscode, etc.)
        hardware = false;         # Hardware tools (pciutils, usbutils, etc.)
        diagnostics = false;      # Diagnostic tools
        monitoring = false;       # Monitoring tools (btop, etc.)
        benchmarking = false;     # Benchmarking tools
      };
      
      # Diagnostics tools (scripts, etc.)
      diagnostics.enable = false;
      
      # Filesystem options (if any specific ones are needed beyond hardware-config)
      # filesystems = {};
    };

    # --------------------------------------------------------------------------
    # Security
    # --------------------------------------------------------------------------
    security = {
      boot.enable = true;         # Boot configuration
      system.enable = true;       # System security settings
      
      # SSH Configuration
      ssh = {
        # enable = true;
        # ports = [ 22 ];
      };
      
      # SOPS Secrets Management
      sops = {
        # enable = true;
        # defaultSopsFile = ../../secrets/secrets.yaml;
      };
      
      # Portmaster Application Firewall
      portmaster = {
        enable = false;
        # dataDir = "/opt/safing/portmaster";
        # ui.enable = false;
        # notifier.enable = false;
      };
      
      # Secure Boot (Lanzaboote)
      # boot.lanzaboote.enable = false;
      
      # Arkenfox (LibreWolf Hardening)
      arkenfox = {
        enable = false;
        # targetDir = "...";
        # user = "user";
        # group = "users";
      };
    };

    # --------------------------------------------------------------------------
    # Hardware Support
    # --------------------------------------------------------------------------
    hardware = {
      base.enable = true;         # Base hardware config (fwupd, etc.)
      networking.enable = true;   # Network configuration
      audio.enable = true;        # PipeWire audio
      power.enable = true;        # Power management
      
      # Performance Tuning
      performance = {
        enable = false;           # Ananicy, zram, etc.
      };
      
      # Graphics Configuration
      graphics = {
        enable = true;            # Base graphics support
        enable32Bit = true;       # 32-bit support (Steam, Wine)
        
        # Vendor specific (enable ONE)
        amd.enable = false;
        intel.enable = false;
        nvidia = {
          enable = false;
          # profile = "stable";   # stable, beta, production, etc.
        };
        
        # Hybrid Graphics (if applicable)
        # ...
      };
      
      # MacBook Specifics
      macbook = {
        # patches = { ... };
      };
    };

    # --------------------------------------------------------------------------
    # Kernel Configuration
    # --------------------------------------------------------------------------
    kernel = {
      enable = true;
      variant = "cachyos";        # cachyos, cachyos-lto, zen, default
      # laptopSafe = false;       # Enable power saving kernel params
      # preferLocalBuild = true;  # Build locally instead of substituting
      # extraParams = [ ... ];    # Extra kernel command line arguments
    };
    
    # Chaotic-Nyx Optimizations
    chaotic.optimizations.enable = false;

    # --------------------------------------------------------------------------
    # Desktop Environment
    # --------------------------------------------------------------------------
    desktop = {
      kde.enable = false;         # KDE Plasma
      flatpak.enable = false;     # Flatpak support
    };

    # --------------------------------------------------------------------------
    # Development
    # --------------------------------------------------------------------------
    development = {
      tools = {
        # Enable specific toolsets if defined in tools.nix
      };
      
      antigravity = {
        enable = false;           # Google Antigravity IDE
        # browser.enable = true;
      };
    };
    
    # --------------------------------------------------------------------------
    # Gaming
    # --------------------------------------------------------------------------
    gaming = {
      enable = false;
      steam = {
        enable = true;
        gamescope = true;
      };
      packages = {
        performance = false;
        cachyos = false;
      };
    };
    
    # --------------------------------------------------------------------------
    # Audio & Music Production
    # --------------------------------------------------------------------------
    music = {
      tidalcycles = {
        enable = false;
        # autostartSuperDirt = false;
      };
    };
    
    # --------------------------------------------------------------------------
    # Virtualization
    # --------------------------------------------------------------------------
    virtualization = {
      libvirt.enable = false;
      vmware.enable = false;
      # vfioHooks = { ... };
    };
    
    # --------------------------------------------------------------------------
    # Wine / Windows Compatibility
    # --------------------------------------------------------------------------
    programs = {
      wine = {
        enable = false;
        # variant = "staging";
      };
      bottles.enable = false;
    };
  };

  # ============================================================================
  # CachyOS Settings
  # ============================================================================
  # Advanced system tuning provided by CachyOS
  myModules.cachyos.settings = {
    enable = false;
    # allowUnsafe = true;
    # applyAllConfigs = true;
    # debug = false;
    # categories = {
    #   desktop = true;
    #   networking = true;
    #   storage = true;
    #   gaming = false;
    #   server = false;
    # };
  };

  # ============================================================================
  # Sched_ext (BPF Scheduler)
  # ============================================================================
  services.scx = {
    enable = false;
    # scheduler = "scx_rusty"; # scx_rusty, scx_lavd, etc.
  };

  # ============================================================================
  # Standard NixOS Configuration
  # ============================================================================
  
  networking.hostName = "template-host"; # CHANGE THIS
  time.timeZone = "Europe/Berlin";
  
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [ "en_US.UTF-8/UTF-8" ];
  };

  # Bootloader
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };
  
  # State Version
  system.stateVersion = "26.05"; # Did you read the comment?
}

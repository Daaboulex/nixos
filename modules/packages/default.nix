{ config, pkgs, lib, ... }:

let
  cfg = config.myModules.system.packages;
in
{
  # ============================================================================
  # Module Options - Package Categories
  # ============================================================================
  options.myModules.system.packages = {
    base = lib.mkEnableOption "Base system utilities (wget, curl, tree, zip, etc.)";
    sync = lib.mkEnableOption "Sync tools (freefilesync, etc.)";
    dev = lib.mkEnableOption "Development tools (gh, git-lfs, sherlock)";
    media = lib.mkEnableOption "Media tools (ffmpeg)";
    mobile = lib.mkEnableOption "Mobile device tools (libimobiledevice, ifuse)";
    editors = lib.mkEnableOption "Text editors (vim, nano)";
    hardware = lib.mkEnableOption "Hardware tools (pciutils, usbutils, lshw, dmidecode, sensors)";
    diagnostics = lib.mkEnableOption "Diagnostics tools (inxi, ethtool, powertop)";
    monitoring = lib.mkEnableOption "System monitoring tools (htop, btop, lact)";
    benchmarking = lib.mkEnableOption "Benchmarking tools (sysbench, stress-ng)";
  };

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkMerge [
    # Base system utilities
    (lib.mkIf cfg.base {
      environment.systemPackages = with pkgs; [
        # Core utilities
        wget
        curl
        tree
        unzip
        zip
        p7zip
        jq
        which
        man-pages
        nix-output-monitor
        comma
        sbctl
        samba
        cifs-utils
        iproute2
        libblockdev
        fastfetch
        libinput

        # Disk utilities
        util-linux
        gptfdisk
        gnugrep
        gnused
        gawk
        coreutils
        testdisk

        
      ];

      # Enable ADB for Android devices
      programs.adb.enable = true;
      users.users.${config.myModules.primaryUser}.extraGroups = [ "adbusers" ];
    })

    # Sync tools
    (lib.mkIf cfg.sync {
      environment.systemPackages = with pkgs; [
        
        freefilesync
      ];
    })

    # Development tools
    (lib.mkIf cfg.dev {
      environment.systemPackages = with pkgs; [
        git
        gh          # GitHub CLI
        git-lfs     # Git Large File Storage
        sherlock    # Find usernames across social networks
        nil         # Nix Language Server
      ];
    })

    # Media tools
    (lib.mkIf cfg.media {
      environment.systemPackages = with pkgs; [
        ffmpeg
      ];
    })

    # Mobile device support
    (lib.mkIf cfg.mobile {
      environment.systemPackages = with pkgs; [
        libimobiledevice  # iOS device support
        ifuse             # Mount iOS devices
      ];
    })

    # Text editors
    (lib.mkIf cfg.editors {
      environment.systemPackages = with pkgs; [
        vim
        nano
      ];
    })

    # Hardware tools
    (lib.mkIf cfg.hardware {
      environment.systemPackages = with pkgs; [
        pciutils        # lspci
        usbutils        # lsusb
        lshw            # Hardware lister
        hwinfo          # Hardware information
        dmidecode       # DMI/SMBIOS decoder
        lm_sensors      # Hardware monitoring
        smartmontools   # S.M.A.R.T. monitoring
        bluez-tools     # Bluetooth utilities
        brightnessctl   # Backlight control
        acpi            # ACPI information
        upower          # Power management
      ];
    })

    # Diagnostics tools
    (lib.mkIf cfg.diagnostics {
      environment.systemPackages = with pkgs; [
        inxi            # System information
        ethtool         # Ethernet tool
        powertop        # Power consumption analyzer
        mesa-demos      # OpenGL demos (glxinfo, glxgears)
        vulkan-tools    # Vulkan utilities (vulkaninfo)
        iw              # Wireless tools
        lsof            # List open files
        minicom         # Serial communication
      ];
    })

    # System monitoring
    (lib.mkIf cfg.monitoring {
      environment.systemPackages = with pkgs; [
        htop        # Interactive process viewer
        btop        # Resource monitor
        lact        # Linux AMDGPU Control Tool
        radeontop   # AMD GPU monitor
      ];
    })

    # Benchmarking tools
    (lib.mkIf cfg.benchmarking {
      environment.systemPackages = with pkgs; [
        sysbench    # System benchmark
        stress-ng   # Stress testing tool
      ];
    })
  ];
}

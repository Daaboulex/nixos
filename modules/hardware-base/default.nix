{ config, pkgs, lib, ... }:

let
  hostName = config.networking.hostName;
  isMacBook = lib.hasPrefix "macbook-pro" hostName;
in
{
  # ============================================================================
  # Module Options
  # ============================================================================
  options.myModules.hardware.base.enable = lib.mkEnableOption "Base hardware configuration";

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf config.myModules.hardware.base.enable {
    # ==========================================================================
    # Firmware and Microcode
    # ==========================================================================
    # Enable all available firmware (including proprietary)
    hardware.enableAllFirmware = true;

    # CPU microcode updates for security and stability
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # ==========================================================================
    # Bluetooth Configuration
    # ==========================================================================
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;  # Automatically power on Bluetooth on boot

      # Bluetooth settings
      settings.General = {
        # Enable all Bluetooth profiles (deprecated in BlueZ 5, profiles are auto-enabled)
        # Enable = "Source,Sink,Media,Socket";
        # Enable experimental features (better compatibility)
        Experimental = true;
      };
    };

    # ==========================================================================
    # Firmware Update Service
    # ==========================================================================
    # fwupd provides firmware updates for UEFI, devices, etc.
    services.fwupd.enable = true;

    # ==========================================================================
    # Thermal Management
    # ==========================================================================
    # thermald prevents overheating on Intel systems
    services.thermald.enable = true;

    # ==========================================================================
    # Kernel Modules
    # ==========================================================================
    boot.kernelModules =
      # coretemp: Intel CPU temperature monitoring (not needed on MacBooks)
      lib.optionals (!isMacBook) [ "coretemp" ]
      # drivetemp: Hard drive temperature monitoring
      ++ [ "drivetemp" ];

    # Blacklist modules that don't exist or cause errors
    boot.blacklistedKernelModules = 
      # Only blacklist cpufreq_schedutil if NOT on MacBook (MacBook uses standard kernel)
      # CachyOS/BORE kernel uses different scheduler - this module doesn't exist
      lib.optionals (!isMacBook) [ "cpufreq_schedutil" ]
      # Desktop-only: suppress i2c MSFT8000 registration error on AMD systems
      # MSFT8000 is a Microsoft HID touchpad device - DO NOT blacklist on MacBook!
      ++ lib.optionals (!isMacBook) [ "i2c_hid_acpi" "i2c_hid" ];
  };
}
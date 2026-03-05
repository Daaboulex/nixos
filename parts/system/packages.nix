{ inputs, ... }: {
  flake.nixosModules.system-packages = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.system.packages;
    in {
      options.myModules.system.packages = {
        base = lib.mkEnableOption "Base system utilities";
        sync = lib.mkEnableOption "Sync tools";
        dev = lib.mkEnableOption "Development tools";
        media = lib.mkEnableOption "Media tools";
        mobile = lib.mkEnableOption "Mobile device tools";
        editors = lib.mkEnableOption "Text editors";
        hardware = lib.mkEnableOption "Hardware tools";
        diagnostics = lib.mkEnableOption "Diagnostics tools";
        monitoring = lib.mkEnableOption "System monitoring tools";
        benchmarking = lib.mkEnableOption "Benchmarking tools";
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.base { environment.systemPackages = with pkgs; [ wget curl tree unzip zip p7zip unrar jq which man-pages nix-output-monitor comma sbctl samba cifs-utils iproute2 libblockdev fastfetch libinput util-linux gptfdisk gnugrep gnused gawk coreutils testdisk gparted android-tools ]; })
        (lib.mkIf cfg.sync { environment.systemPackages = [ pkgs.freefilesync ]; })
        (lib.mkIf cfg.dev { environment.systemPackages = with pkgs; [ git gh git-lfs sherlock nil ]; })
        (lib.mkIf cfg.media { environment.systemPackages = [ pkgs.ffmpeg ]; })
        (lib.mkIf cfg.mobile { environment.systemPackages = with pkgs; [ libimobiledevice ifuse ]; })
        (lib.mkIf cfg.editors { environment.systemPackages = with pkgs; [ vim nano ]; })
        (lib.mkIf cfg.hardware { environment.systemPackages = with pkgs; [ pciutils usbutils lshw hwinfo dmidecode lm_sensors smartmontools bluez-tools brightnessctl acpi upower ]; })
        (lib.mkIf cfg.diagnostics { environment.systemPackages = with pkgs; [ inxi ethtool powertop mesa-demos vulkan-tools iw lsof minicom ]; })
        (lib.mkIf cfg.monitoring { environment.systemPackages = with pkgs; [ ]
          ++ lib.optionals (config.myModules.hardware.graphics.amd.enable or false) [ lact radeontop ]; })
        (lib.mkIf cfg.benchmarking { environment.systemPackages = with pkgs; [ sysbench stress-ng ]; })
      ];
    };
}

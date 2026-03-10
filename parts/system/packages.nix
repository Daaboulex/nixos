{ inputs, ... }: {
  flake.nixosModules.system-packages = { config, lib, pkgs, ... }:
    let
      cfg = config.myModules.system.packages;
    in {
      _class = "nixos";
      options.myModules.system.packages = {
        enable = lib.mkEnableOption "System packages";
        base = lib.mkOption { type = lib.types.bool; default = true; description = "Base system utilities (wget, curl, jq, etc.)"; };
        dev = lib.mkOption { type = lib.types.bool; default = true; description = "Developer CLI tools (nil, sherlock)"; };
        media = lib.mkOption { type = lib.types.bool; default = true; description = "Media processing tools (ffmpeg)"; };
        mobile = lib.mkOption { type = lib.types.bool; default = true; description = "Mobile device connectivity (iOS)"; };
        editors = lib.mkOption { type = lib.types.bool; default = true; description = "Terminal text editors (vim, nano)"; };
        hardware = lib.mkOption { type = lib.types.bool; default = true; description = "Hardware inspection and monitoring tools"; };
        diagnostics = lib.mkOption { type = lib.types.bool; default = true; description = "System diagnostics tools"; };
        monitoring = lib.mkOption { type = lib.types.bool; default = true; description = "GPU and system monitoring tools"; };
        benchmarking = lib.mkOption { type = lib.types.bool; default = false; description = "Benchmarking and stress-testing tools"; };
      };

      config = lib.mkIf cfg.enable (lib.mkMerge [
        (lib.mkIf cfg.base { environment.systemPackages = with pkgs; [ wget curl tree unzip zip p7zip unrar jq which man-pages nix-output-monitor comma sbctl samba cifs-utils iproute2 libblockdev fastfetch libinput util-linux gptfdisk gnugrep gnused gawk coreutils testdisk gparted android-tools ]; })
        (lib.mkIf cfg.dev { environment.systemPackages = with pkgs; [
          # git, gh, git-lfs: owned by HM git module
          sherlock nil
        ]; })
        (lib.mkIf cfg.media { environment.systemPackages = [ pkgs.ffmpeg ]; })
        (lib.mkIf cfg.mobile { environment.systemPackages = with pkgs; [ libimobiledevice ifuse ]; })
        (lib.mkIf cfg.editors { environment.systemPackages = with pkgs; [ vim nano ]; })
        (lib.mkIf cfg.hardware { environment.systemPackages = with pkgs; [ pciutils usbutils lshw hwinfo dmidecode lm_sensors smartmontools bluez-tools brightnessctl acpi upower ]; })
        (lib.mkIf cfg.diagnostics { environment.systemPackages = with pkgs; [ inxi ethtool powertop mesa-demos vulkan-tools iw lsof minicom ]; })
        (lib.mkIf cfg.monitoring { environment.systemPackages = with pkgs; [ ]
          ++ lib.optionals (config.myModules.hardware.graphics.amd.enable or false) [ lact radeontop ]; })
        (lib.mkIf cfg.benchmarking { environment.systemPackages = with pkgs; [ sysbench stress-ng ]; })
      ]);
    };
}

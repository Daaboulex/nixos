# sysdiag — system diagnostics helper script with theme-aware output.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.sysdiag;
  inherit (myLib.themeCtx { inherit config; }) hasTheme theme;
  scriptText = import ./sysdiag-script.nix {
    colors = if hasTheme then theme.colors else null;
  };
  # Complete runtime-dependency manifest, pinned into PATH so sysdiag is fully
  # self-contained — it works under sudo's restricted PATH and never relies on
  # whatever the ambient/system PATH happens to provide. Deliberately ambient
  # (from the :$PATH tail, never pinned): sudo (setuid system binary),
  # nvidia-smi (driver-provided), lact (service-provided) — host-specific and
  # guarded in the script.
  runtimeDeps = with pkgs; [
    coreutils # cat cut df head tail sort wc readlink uname timeout env uniq
    findutils # xargs
    gawk
    gnugrep
    gnused
    util-linux # dmesg lscpu lsblk ipcs swapon
    procps # free top ps uptime pgrep
    systemd # systemctl journalctl systemd-analyze loginctl
    btrfs-progs
    nvme-cli
    pciutils # lspci
    usbutils # lsusb
    iproute2 # ip ss tc
    ethtool
    kmod
    lm_sensors
    smartmontools
    upower
    mesa-demos # glxinfo
    vulkan-tools
    kdePackages.libkscreen # kscreen-doctor
    wlr-randr
    xrandr # X11 fallback for the displays section
    fastfetch
  ];
  sysdiag = pkgs.writeShellScriptBin "sysdiag" ''
    export PATH="${lib.makeBinPath runtimeDeps}:$PATH"
    ${scriptText}
  '';
in
{
  options.myModules.home.sysdiag = {
    enable = lib.mkEnableOption "sysdiag system diagnostics script";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ sysdiag ];
  };
}

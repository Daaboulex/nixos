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
    inherit pkgs;
    colors = if hasTheme then theme.colors else null;
  };
  # Complete runtime-dependency manifest, pinned into PATH so sysdiag is fully
  # self-contained — it works under sudo's restricted PATH and never relies on
  # whatever the ambient/system PATH happens to provide.
  runtimeDeps = with pkgs; [
    coreutils # cat cut df head tail sort wc readlink uname
    gawk
    gnugrep
    gnused
    util-linux # dmesg lscpu lsblk
    procps # free top ps uptime
    systemd # systemctl journalctl systemd-analyze loginctl
    btrfs-progs
    nvme-cli
    pciutils # lspci
    usbutils # lsusb
    iproute2 # ip
    ethtool
    kmod
    lm_sensors
    smartmontools
    upower
    mesa-demos # glxinfo
    vulkan-tools
    kdePackages.libkscreen # kscreen-doctor
    wlr-randr
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

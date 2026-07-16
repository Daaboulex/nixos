# flatpak — declarative Flatpak management via nix-flatpak with flathub remote.
{
  config,
  lib,
  pkgs,
  inputs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.flatpak;
  inherit (myLib.themeCtx { inherit config; }) hasTheme;
in
{
  # imports MUST be unconditional — cannot be inside mkIf
  imports = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];

  options.myModules.home.flatpak = {
    enable = lib.mkEnableOption "declarative Flatpak management via nix-flatpak";
    settings = myLib.mkSettingsOption { };
  };

  config = lib.mkIf cfg.enable {
    # Why: nix-flatpak's generated unit has Restart=on-failure + RestartSec=60s,
    # which logs "Failed to start" every time flathub is briefly unreachable
    # (e.g. post-wake, VPN reconnect). Ordering the service AFTER
    # network-online.target lets the first attempt wait for the system to
    # reach that target before firing, which eliminates the boot-time /
    # wake-time false-failure pattern. User units can legally order on system
    # targets; they just can't Wants= them (the system instance triggers
    # network-online.target itself via NetworkManager-wait-online.service).
    systemd.user.services.flatpak-managed-install-timer = {
      Unit.After = [ "network-online.target" ];
    };

    services.flatpak = myLib.mergeSettings {
      defaults = {
        enable = true;

        remotes = lib.mkOptionDefault [
          {
            name = "flathub";
            location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
          }
        ];

        update.onActivation = false;
        update.auto.enable = lib.mkDefault true;
        update.auto.onCalendar = lib.mkDefault "daily";

        overrides = {
          global = {
            Context.sockets = [
              "wayland"
              "pulseaudio"
            ];

            Environment =
              if hasTheme then
                {
                  GTK_THEME = "Breeze-Dark";
                  ICON_THEME = "breeze-dark";
                  XCURSOR_THEME = "breeze_cursors";
                  XCURSOR_PATH = "/run/host/user-share/icons:/run/host/share/icons";
                  QT_STYLE_OVERRIDE = "Breeze";
                }
              else
                { };

            Context.filesystems = [
              "xdg-config/gtk-3.0:ro"
              "xdg-config/gtk-4.0:ro"
              "/usr/share/themes:ro"
              "/usr/share/icons:ro"
              "~/.themes:ro"
              "~/.icons:ro"
            ];
          };

          # Ungoogled-Chromium on Ivy Bridge HD 4000: HW video decode on kernel 7.0
          # is unusable. intel-vaapi-driver (i965) is abandoned upstream and its
          # `i965_drv_video.so` fails `va_openDriver()` on kernel 7.0 — confirmed
          # via `vainfo` returning `VA_STATUS_ERROR_UNKNOWN` inside the Flatpak.
          # intel-media-driver (iHD) is Broadwell+, SIGTRAPs on HD 4000 in
          # `video_capture.mojom.VideoCaptureService` on every WebRTC page.
          # Setting `LIBVA_DRIVER_NAME=none` tells libva no driver is available,
          # so chromium falls back to SW decode and stops crashing. SW decode is
          # fine — HD 4000 HW decode was already slower than the CPU path.
          "io.github.ungoogled_software.ungoogled_chromium".Environment = {
            LIBVA_DRIVER_NAME = "none";
          };
        };
      };
      overrides = cfg.settings;
    };
  };
}

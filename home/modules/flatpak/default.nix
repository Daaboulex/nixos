# Flatpak Module - Declarative Flatpak management via nix-flatpak (Home Manager)
#
# Shared Flatpak configuration. Host-specific packages are in home/hosts/<hostname>/default.nix
#
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];

  services.flatpak = {
    enable = true;

    # Add Flathub remote
    remotes = lib.mkOptionDefault [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    # Auto-update apps daily
    update.onActivation = false;
    update.auto.enable = true;
    update.auto.onCalendar = "daily";

    # Global overrides for all Flatpak apps - enforce dark theme
    overrides = {
      global = {
        # Force Wayland by default but keep audio working
        Context.sockets = [
          "wayland"
          "pulseaudio"
        ];

        # Theming environment variables (override per-host if using a different theme)
        Environment = lib.mkDefault {
          GTK_THEME = "Breeze-Dark";
          ICON_THEME = "breeze-dark";
          XCURSOR_THEME = "breeze_cursors";
          # Fix un-themed cursor in some Wayland apps
          XCURSOR_PATH = "/run/host/user-share/icons:/run/host/share/icons";
          # Force Qt apps to use Breeze style
          QT_STYLE_OVERRIDE = "Breeze";
        };
        # Allow access to system themes
        Context.filesystems = [
          "xdg-config/gtk-3.0:ro"
          "xdg-config/gtk-4.0:ro"
          "/usr/share/themes:ro"
          "/usr/share/icons:ro"
          "~/.themes:ro"
          "~/.icons:ro"
        ];
      };
    };
  };
}

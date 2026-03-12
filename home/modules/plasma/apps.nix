# Plasma App Configuration
# configFile entries for KDE apps without their own standalone module
{
  config,
  pkgs,
  lib,
  osConfig,
  ...
}:

{
  programs.plasma.configFile = {
    # ---- Locale (English UI, German date/time/number formats) ----
    # Override per-host for different locale preferences
    "plasma-localerc"."Formats" = {
      LANG = lib.mkDefault "en_US.UTF-8";
      LC_TIME = lib.mkDefault "de_DE.UTF-8";
      LC_NUMERIC = lib.mkDefault "de_DE.UTF-8";
      LC_MONETARY = lib.mkDefault "de_DE.UTF-8";
      LC_MEASUREMENT = lib.mkDefault "de_DE.UTF-8";
      LC_PAPER = lib.mkDefault "de_DE.UTF-8";
      LC_COLLATE = lib.mkDefault "de_DE.UTF-8";
    };

    # ---- Timezone (derived from NixOS time.timeZone) ----
    "ktimezonedrc"."TimeZones" = {
      LocalZone = osConfig.time.timeZone;
      ZoneinfoDir = "/etc/zoneinfo";
      Zonetab = "/etc/zoneinfo/zone.tab";
    };

    # ---- KDE Daemon ----
    "kded5rc"."Module-browserintegrationreminder" = {
      autoload = lib.mkDefault false;
    };

    "kded5rc"."Module-device_automounter" = {
      autoload = lib.mkDefault false; # Don't auto-mount removable devices (security)
    };

    # ---- Activity Manager ----
    "kactivitymanagerdrc"."Plugins" = {
      "org.kde.ActivityManager.ResourceScoringEnabled" = lib.mkDefault true;
    };

    # ---- Klipper (Clipboard) ----
    "klipperrc"."General" = {
      KeepClipboardContents = lib.mkDefault false; # Clear clipboard on logout/poweroff (safety)
      MaxClipItems = lib.mkDefault 25;
      PreventEmptyClipboard = lib.mkDefault true;
      SyncClipboards = lib.mkDefault true; # Selection ↔ clipboard sync
    };

    # ---- Dolphin (File Manager) ----
    "dolphinrc"."MainWindow" = {
      MenuBar = lib.mkDefault "Disabled"; # Use hamburger menu instead
    };

    "dolphinrc"."KFileDialog Settings" = {
      "Places Icons Auto-resize" = lib.mkDefault false;
      "Places Icons Static Size" = lib.mkDefault 22;
    };

    # ---- Baloo (File Indexing) ----
    # Override per-host if different exclusion lists are needed
    "baloofilerc"."General" =
      let
        home = config.home.homeDirectory;
      in
      {
        "first run" = false;
        "exclude folders" = lib.mkDefault (
          lib.concatStringsSep "," [
            "${home}/.cache"
            "${home}/.local/share/Steam"
            "${home}/.local/share/lutris"
            "${home}/.wine"
            "${home}/.npm"
            "${home}/.cargo"
            "${home}/.rustup"
            "/tmp"
            "/nix"
          ]
        );
      };

    # ---- KWallet ----
    "kwalletrc"."Wallet" = {
      "First Use" = false;
    };

    # ---- KIO ----
    "kiorc"."Confirmations" = {
      ConfirmEmptyTrash = lib.mkDefault true;
      ConfirmDelete = lib.mkDefault true; # Confirm permanent delete (Shift+Del)
    };

    # ---- Notifications ----
    "plasmanotifyrc"."DoNotDisturb" = {
      WhenScreensMirrored = lib.mkDefault true; # Auto-DND when screen mirroring (presentations)
    };

    # ---- Gwenview (Image Viewer) ----
    "gwenviewrc"."MainWindow" = {
      MenuBar = lib.mkDefault "Disabled";
    };

    "gwenviewrc"."General" = {
      SideBarPage = lib.mkDefault "operations";
    };

    "gwenviewrc"."ThumbnailView" = {
      AutoplayVideos = lib.mkDefault true;
    };

    # ---- Ark (Archive Manager) ----
    "arkrc"."General" = {
      LockSidebar = lib.mkDefault true;
      ShowSidebar = lib.mkDefault true;
    };

    "arkrc"."MainWindow" = {
      StatusBar = lib.mkDefault "Disabled";
    };

    # ---- KWrite (Simple Text Editor) ----
    "kwriterc"."General" = {
      "Days Meta Infos" = lib.mkDefault 30;
      "Save Meta Infos" = lib.mkDefault true;
      "Show Full Path in Title" = lib.mkDefault false;
      "Show Menu Bar" = lib.mkDefault false;
      "Show Status Bar" = lib.mkDefault true;
      "Show Tab Bar" = lib.mkDefault true;
      "Show Url Nav Bar" = lib.mkDefault false;
    };
  };
}

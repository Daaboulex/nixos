# plasma — KDE Plasma core packages, programs.plasma.enable, and app configFile entries.
# Sub-modules handle appearance, kwin, panels, power, and shortcuts independently.
{
  config,
  pkgs,
  lib,
  myLib,
  inputs,
  osConfig ? { },
  ...
}:

let
  cfg = config.myModules.home.plasma;
in
{
  imports = [
    inputs.plasma-manager.homeModules.plasma-manager
    ./appearance.nix
    ./clipboard.nix
    ./kwin.nix
    ./panels.nix
    ./power.nix
    ./shortcuts.nix
    ./input.nix
  ];

  options.myModules.home.plasma = {
    enable = lib.mkEnableOption "KDE Plasma core packages and programs.plasma.enable";
    gpuBackend = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "vulkan"
          "opengl"
          "software"
        ]
      );
      default = null;
      description = "Force a specific QtQuick/RHI rendering backend (vulkan recommended for RDNA3+).";
    };
    discoverNotifier = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to run the plasma-discover notifier at session start (the small
        tray icon that polls for system/Flatpak updates). Disable to silence the
        spurious `cupsd client-error-bad-request for Create-Printer-Subscriptions`
        log entries at login — plasma-discover sends a malformed IPP subscription
        request on startup to watch for printer firmware updates, which cupsd
        rejects with client-error-bad-request before the notifier retries with a
        correct payload. Disabling the notifier removes the log noise without
        affecting Discover launched manually.
      '';
    };
    defaultTerminal = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default =
        if config.myModules.home.ghostty.enable then
          "com.mitchellh.ghostty.desktop"
        else if config.myModules.home.konsole.enable then
          "org.kde.konsole.desktop"
        else
          null;
      defaultText = lib.literalMD "ghostty if enabled, else konsole, else null";
      description = ''
        Desktop-id of the KDE default terminal — single source of truth for the
        kdeglobals TerminalService (appearance.nix) and the Ctrl+Alt+T launch
        shortcut (shortcuts.nix). Auto-selects ghostty > konsole from what is
        enabled, so the reference can never dangle; override per host if needed.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Wayland session variables for Electron/SDL/Qt apps
      (myLib.mkSessionVars (
        {
          NIXOS_OZONE_WL = lib.mkDefault "1";
          SDL_VIDEODRIVER = lib.mkDefault "wayland";
        }
        // lib.optionalAttrs (cfg.gpuBackend != null) {
          QSG_RHI_BACKEND = cfg.gpuBackend;
        }
      ))
      {
        programs.plasma.enable = true;

        # A plasma host must have a terminal for the default-terminal + Ctrl+Alt+T
        # wiring to resolve. Fail-fast instead of dangling on an absent app.
        assertions = [
          {
            assertion = cfg.defaultTerminal != null;
            message = "myModules.home.plasma is enabled but neither ghostty nor konsole is — the default terminal (kdeglobals TerminalService + Ctrl+Alt+T) has no target. Enable a terminal module or set plasma.defaultTerminal.";
          }
        ];

        home.packages = with pkgs; [
          # Core KDE utilities
          kdePackages.kcalc # Calculator
          kdePackages.kcharselect # Special character selector
          kdePackages.kclock # Clock app
          kdePackages.kcolorchooser # Color picker
          # File management & disk tools
          kdePackages.filelight # Disk usage analyzer
          kdePackages.isoimagewriter # Write ISO to USB
          kdePackages.partitionmanager # Partition manager
          kdePackages.plasma-disks # Disk health monitoring
          # kio-extras NOT here: stock plasma6 already installs it system-wide
          # (requiredPackages); a second HM copy duplicated its org.kde.kmtpd5 dbus
          # service ("Ignoring duplicate name"). mtp:/ etc. still work via the system copy.

          # System & Connectivity
          kdePackages.kdeconnect-kde # Phone integration
          kdePackages.ksystemlog # System log viewer
          kdePackages.baloo # File indexer

          # Wayland utilities
          wayland-utils
          wl-clipboard # Clipboard

          # KDE debugging & diagnostics
          kdePackages.kdebugsettings # Configure Qt/KDE debug logging categories
          kdePackages.plasma-sdk # Plasma development & debugging tools (plasmoidviewer, etc.)
        ];

        # Mask plasma-discover notifier autostart when the user doesn't want it.
        # Writes a user-level drop-in with Hidden=true, which XDG autostart treats as
        # "do not launch". Keeps Discover itself launchable from the app launcher.
        xdg.configFile = lib.mkIf (!cfg.discoverNotifier) {
          "autostart/org.kde.discover.notifier.desktop".text = ''
            [Desktop Entry]
            Type=Application
            Name=Discover
            Hidden=true
          '';
        };

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
            LocalZone = lib.mkDefault (
              if (osConfig ? time && osConfig.time ? timeZone) then osConfig.time.timeZone else "UTC"
            );
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
              "only basic indexing" = lib.mkDefault true; # Skip content indexing — index filenames/metadata only (much lighter)
              # Redirected dev-tool state dirs come from dev-dirs (single source), so
              # this list never drifts from where the tools actually write. npm's
              # cache lands under ~/.cache, already excluded below.
              "exclude folders" = lib.mkDefault (
                lib.concatStringsSep "," (
                  [
                    "${home}/.cache"
                    "${home}/.local/share/Steam"
                    "${home}/.local/share/lutris"
                    "${home}/.local/share/flatpak"
                    "${home}/.local/share/baloo"
                    "${home}/.var"
                    "${home}/.wine"
                    "${home}/.local/share/Trash"
                    "${home}/Documents/nix/.git"
                    "/tmp"
                    "/nix"
                    "/var"
                  ]
                  ++ lib.optionals config.myModules.home.dev-dirs.enable config.myModules.home.dev-dirs.stateDirs
                )
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

          # ---- Shell & Style (Disabling Blur/Translucency) ----
          "plasmarc"."Wallpapers" = {
            translucency = lib.mkDefault "opaque";
          };

          "breezerc"."Common" = {
            MenuOpacity = lib.mkDefault 100; # 100% Opaque
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

        # Notes on Settings NOT Manageable via plasma-manager:
        # - kwinoutputconfig.json (monitor VRR, HDR, color depth) - hardware-specific
        # - Per-screen wallpapers
      }
    ]
  );
}

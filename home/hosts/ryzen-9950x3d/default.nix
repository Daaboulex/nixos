{ config, lib, ... }:

let
  flatpakApp =
    id:
    "file://${config.home.homeDirectory}/.local/share/flatpak/exports/share/applications/${id}.desktop";
in

{
  imports = [
    ./goxlr.nix
    ./coolercontrol.nix
    ./streamcontroller.nix
  ];
  # ============================================================================
  # Ryzen 9950X3D Home Manager Host Configuration — Exhaustive Reference
  # ============================================================================
  # Every HM module toggle is listed explicitly so this file serves as a
  # display config. Options using their module default are marked # (default).
  # ============================================================================

  # --------------------------------------------------------------------------
  # Git credentials (per-host)
  # --------------------------------------------------------------------------
  programs.git.settings.user = {
    name = "Daaboulex";
    email = "39669593+Daaboulex@users.noreply.github.com";
  };

  # --------------------------------------------------------------------------
  # Home Manager Module Toggles
  # --------------------------------------------------------------------------
  # Core tools
  programs.bat.enable = true; # (default) — syntax-highlighted cat
  programs.fzf.enable = true; # (default) — fuzzy finder
  programs.zoxide.enable = true; # (default) — smart cd
  programs.direnv.enable = true; # (default) — auto-load envrc
  programs.starship.enable = true; # (default) — modern prompt
  programs.zsh.enable = true; # (default) — shell config
  programs.git.enable = true; # (default) — git + lfs

  # Editors & viewers
  programs.vscode.enable = true;
  programs.kate.enable = true; # (default) — KDE text editor
  programs.konsole.enable = true; # (default) — KDE terminal
  programs.okular.enable = true; # (default) — PDF viewer

  # System monitors
  programs.btop.enable = true;
  programs.htop.enable = false; # Redundant with btop on powerful hardware

  # KDE apps — disabled
  programs.ghostwriter.enable = false; # Markdown editor — not using
  programs.elisa.enable = false; # KDE music player — not using (Spotify via Flatpak)

  # Desktop
  programs.plasma.enable = true; # (default) — KDE Plasma settings
  gtk.enable = true; # (default) — GTK theme
  xdg.enable = true; # (default) — XDG directories

  # Audio
  services.easyeffects.enable = false; # GoXLR handles all audio processing

  # Flatpak
  services.flatpak.enable = true; # (default) — declarative Flatpak management

  # --------------------------------------------------------------------------
  # Host-Specific Plasma Settings
  # --------------------------------------------------------------------------

  # Logitech G502 — disable acceleration (handled by yeetmouse)
  # Three device IDs: yeetmouse virtual (407f), wired (c08d), wireless receiver (c539)
  programs.plasma.input.mice = [
    {
      name = "Logitech G502";
      vendorId = "046d";
      productId = "407f"; # yeetmouse virtual device
      acceleration = 0;
      accelerationProfile = "none";
    }
    {
      name = "Logitech G502 LIGHTSPEED Wireless Gaming Mouse";
      vendorId = "046d";
      productId = "c08d"; # wired USB
      acceleration = 0;
      accelerationProfile = "none";
    }
    {
      name = "Logitech G502 LIGHTSPEED Wireless Gaming Mouse";
      vendorId = "046d";
      productId = "c539"; # wireless receiver
      acceleration = 0;
      accelerationProfile = "none";
    }
  ];

  # Desktop — no auto-lock or lock-on-resume
  programs.plasma.kscreenlocker = {
    autoLock = false;
    lockOnResume = false;
  };

  # Desktop power: module defaults (never suspend, balanced) are correct for desktop
  # No overrides needed — mkDefault in module covers this

  # Panel layout (desktop has Antigravity launcher)
  programs.plasma.panels = lib.mkForce [
    {
      location = "bottom";
      height = 44;
      floating = false;
      lengthMode = "fill";
      widgets = [
        {
          name = "org.kde.plasma.kickoff";
          config.General.favoritesPortedToKAstats = "true";
        }
        "org.kde.plasma.pager"
        {
          name = "org.kde.plasma.icontasks";
          config.General = {
            launchers = [
              (flatpakApp "io.gitlab.librewolf-community")
              (flatpakApp "io.github.ungoogled_software.ungoogled_chromium")
              (flatpakApp "eu.betterbird.Betterbird")
              "applications:systemsettings.desktop"
              "preferred://filemanager"
              "applications:antigravity.desktop"
            ];
          };
        }
        "org.kde.plasma.marginsseparator"
        {
          name = "org.kde.plasma.systemtray";
          config.General.showVirtualDevices = "true";
        }
        {
          name = "org.kde.plasma.digitalclock";
          config.Appearance = {
            use24hFormat = "2"; # 2 = force 24h (0 = locale, 1 = force 12h)
          };
        }
      ];
    }
  ];

  # btop GPU layout (gpu0 = Zen 5 iGPU, gpu1 = RX 9070 XT)
  programs.btop.settings = {
    selected_preset = lib.mkForce 0;
    shown_boxes = lib.mkForce "cpu gpu0 gpu1 mem proc";
    presets = lib.mkForce "cpu:0:default,gpu0:0:default,gpu1:0:default,mem:0:default,proc:0:default cpu:0:default,gpu0:0:default,gpu1:0:default,mem:0:default,net:0:default,proc:0:default";
    show_cpu_watts = lib.mkDefault true;
  };

  # --------------------------------------------------------------------------
  # Flatpak Packages (host-specific)
  # --------------------------------------------------------------------------
  services.flatpak.packages = [
    "com.calibre_ebook.calibre"
    "com.github.tenderowl.frog"
    "com.github.jeromerobert.pdfarranger"
    "com.github.Darazaki.Spedread"
    "com.logseq.Logseq"
    "com.obsproject.Studio"
    "com.spotify.Client"
    "com.rtosta.zapzap"
    "de.bund.ausweisapp.ausweisapp2"
    "dev.geopjr.Calligraphy"
    "eu.betterbird.Betterbird"
    "io.github.shiftey.Desktop"
    "io.github.milkshiift.GoofCord"
    "io.github.flattool.Ignition"
    "io.github.giantpinkrobots.flatsweep"
    "io.github.ungoogled_software.ungoogled_chromium"
    "io.gitlab.librewolf-community"
    "md.obsidian.Obsidian"
    "org.ardour.Ardour"
    "org.cryptomator.Cryptomator"
    "org.gimp.GIMP"
    "org.gnome.meld"
    "org.kde.kdenlive"
    "org.kicad.KiCad"
    "org.libreoffice.LibreOffice"
    "org.remmina.Remmina"
    "org.signal.Signal"
    "org.videolan.VLC"
  ];

  # App-specific overrides
  services.flatpak.overrides = {
    "org.signal.Signal".Environment = {
      SIGNAL_PASSWORD_STORE = "kwallet6";
    };
  };

  # --------------------------------------------------------------------------
  # SSH Client Configuration (for remote deployment to MacBook)
  # --------------------------------------------------------------------------
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "macbook" = {
        hostname = "macbook-pro-9-2.local"; # mDNS — avahi resolves .local hostnames
        user = "root";
        identityFile = "~/.ssh/id_ed25519";
        extraOptions = {
          StrictHostKeyChecking = "accept-new"; # Auto-accept on first connect, verify after
        };
      };
      "macbook-user" = {
        hostname = "macbook-pro-9-2.local";
        user = "user";
        identityFile = "~/.ssh/id_ed25519";
        extraOptions = {
          StrictHostKeyChecking = "accept-new";
        };
      };
    };
  };

  # GoXLR, CoolerControl, StreamController — split into separate files:
  # ./goxlr.nix, ./coolercontrol.nix, ./streamcontroller.nix
}

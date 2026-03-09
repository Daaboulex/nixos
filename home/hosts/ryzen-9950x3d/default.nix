{ config, lib, ... }:

let
  flatpakApp = id: "file://${config.home.homeDirectory}/.local/share/flatpak/exports/share/applications/${id}.desktop";
in

{
  # ============================================================================
  # Ryzen 9950X3D Host Configuration
  # ============================================================================

  # Git credentials
  programs.git.settings.user = {
    name = "Daaboulex";
    email = "39669593+Daaboulex@users.noreply.github.com";
  };

  # Enable standard tools
  programs.btop.enable = true;
  programs.htop.enable = false;
  programs.vscode.enable = true;

  # Audio
  services.easyeffects.enable = false;

  # ============================================================================
  # Host-Specific Hardware Settings
  # ============================================================================

  # Night light location (Berlin)
  programs.plasma.kwin.nightLight.location = {
    latitude = "52.52";
    longitude = "13.405";
  };

  # Logitech G502 — disable acceleration (handled by yeetmouse)
  # All three device IDs: yeetmouse virtual (407f), wired (c08d), wireless receiver (c539)
  programs.plasma.configFile."kcminputrc" = let
    flatAccel = {
      PointerAcceleration = "0";
      PointerAccelerationProfile = 1;  # 1 = flat
    };
  in {
    "Libinput][1133][16511][Logitech G502" = flatAccel;              # yeetmouse (046d:407f)
    "Libinput][1133][49293][Logitech G502 LIGHTSPEED Wireless Gaming Mouse" = flatAccel;  # wired (046d:c08d)
    "Libinput][1133][50489][Logitech G502 LIGHTSPEED Wireless Gaming Mouse" = flatAccel;  # wireless (046d:c539)
  };

  # Desktop — no auto-lock or lock-on-resume
  programs.plasma.kscreenlocker = {
    autoLock = false;
    lockOnResume = false;
  };

  # Desktop power: module defaults (never suspend, balanced) are correct for desktop
  # No overrides needed — mkDefault in module covers this

  # Panel launchers (desktop has Antigravity)
  programs.plasma.panels = lib.mkForce [
    {
      location = "bottom";
      height = 70;
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
            autoFontAndSize = "true";
            fontWeight = "400";
            use24hFormat = "2";           # 2 = force 24h (0 = locale, 1 = force 12h)
            dateFormat = "custom";
            customDateFormat = "dd.MM.yyyy";
            dateDisplayFormat = "BesideTime";  # "BesideTime" or "BelowTime"
            showDate = "true";
            showSeconds = "Never";        # "Never", "InToolTip", "Always"
          };
        }
      ];
    }
  ];

  # btop GPU layout (gpu0 = Zen 5 iGPU, gpu1 = RX 9070 XT)
  programs.btop.settings = {
    selected_preset = lib.mkForce 0;
    shown_boxes = lib.mkForce "cpu gpu0 gpu1 mem proc";
    presets = lib.mkForce "cpu:0:default,gpu1:0:default,mem:0:default,proc:0:default cpu:0:default,gpu0:0:default,gpu1:0:default,mem:0:default,net:0:default,proc:0:default";
  };

  # ============================================================================
  # Flatpak Packages (host-specific)
  # ============================================================================
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

}
